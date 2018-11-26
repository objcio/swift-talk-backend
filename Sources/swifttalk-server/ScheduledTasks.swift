//
//  ScheduledTasks.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 13-11-2018.
//

import Foundation
import PostgreSQL

enum Task {
    case syncTeamMembersWithRecurly(userId: UUID)
    case releaseEpisode(number: Int)
}

struct TaskError: Error {
    var message: String
}

extension Task: Codable {
    enum CodingKeys: CodingKey {
        case syncTeamMembersWithRecurly
        case releaseEpisode
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .syncTeamMembersWithRecurly(let userId):
            try container.encode(userId, forKey: .syncTeamMembersWithRecurly)
        case .releaseEpisode(let number):
            try container.encode(number, forKey: .releaseEpisode)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decode(UUID.self, forKey: .syncTeamMembersWithRecurly) {
            self = .syncTeamMembersWithRecurly(userId: id)
        } else if let number = try? container.decode(Int.self, forKey: .releaseEpisode) {
            self = .releaseEpisode(number: number)
        } else {
            throw TaskError(message: "Unable to decode")
        }
    }
    
    func uniqueKey(for date: Date) -> String {
        switch self {
        case .syncTeamMembersWithRecurly(let userId):
            return "\(CodingKeys.syncTeamMembersWithRecurly.stringValue):\(userId.uuidString)"
        case .releaseEpisode(let number):
            return "\(CodingKeys.releaseEpisode.stringValue):\(number):\(date.timeIntervalSinceReferenceDate)"
        }
    }
}

struct TaskData: Insertable {
    var date: Date
    var json: String
    var key: String
    
    init(date: Date, task: Task) {
        self.date = date
        let data = try! JSONEncoder().encode(task)
        self.json = String(data: data, encoding: .utf8)!
        self.key = task.uniqueKey(for: date)
    }

    static var tableName = "tasks"
}

extension Task {
    func schedule(at date: Date) -> Query<()> {
        let taskData = TaskData(date: date, task: self)
        return taskData.insertOrUpdate(uniqueKey: "key").map { _ in }
    }
    
    func interpret(_ c: Lazy<Connection>, onCompletion: @escaping (Bool) -> ()) throws {
        switch self {
        case .syncTeamMembersWithRecurly(let userId):
            guard let user = try c.get().execute(Row<UserData>.select(userId)) else { onCompletion(true); return }
            let teamMembers = try c.get().execute(user.teamMembers)
            user.currentSubscription.promise.flatMap { (sub: Subscription??) -> Promise<Subscription?> in
                guard let su = sub, let s = su else { return Promise { $0(nil) } }
                return recurly.updateSubscription(s, numberOfTeamMembers: teamMembers.count).promise
            }.run { sub in
                onCompletion(sub?.subscription_add_ons.first?.quantity == teamMembers.count)
            }
        
        case .releaseEpisode(let number):
            guard let ep = Episode.all.first(where: { $0.number == number }) else { onCompletion(true); return }
            let sendCampaign: Promise<Bool> = mailchimp.createCampaign(for: ep).promise.flatMap { campaignId in
                guard let id = campaignId else { return Promise { $0(false) } }
                return mailchimp.addContent(for: ep, toCampaign: id).promise.flatMap { _ in
                    if env.production {
                        // TODO here we have to actually send the campaign
                        return mailchimp.testCampaign(campaignId: id).promise.map { $0 != nil }
                    } else {
                        return mailchimp.testCampaign(campaignId: id).promise.map { $0 != nil }
                    }
                }
            }

            github.changeVisibility(private: false, of: ep.id.rawValue).promise.flatMap { _ in
                circle.triggerMainSiteBuild.promise
            }.flatMap { _ in
                mailchimp.existsCampaign(for: ep).promise
            }.flatMap { campaignExists in
                return campaignExists == false ? sendCampaign : Promise { $0(false) }
            }.run { success in
                onCompletion(success)
            }
        }
    }
}

extension Row where Element == TaskData {
    func process(_ c: Lazy<Connection>, onCompletion: @escaping (Bool) -> ()) throws {
        let task = try JSONDecoder().decode(Task.self, from: self.data.json.data(using: .utf8)!)
        try task.interpret(c) { success in
            if success {
                tryOrLog("Failed to delete task \(self.id) from database") { try c.get().execute(self.delete) }
            }
            onCompletion(success)
        }
    }
}
