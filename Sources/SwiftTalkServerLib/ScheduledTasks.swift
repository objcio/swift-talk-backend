//
//  ScheduledTasks.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 13-11-2018.
//

import Foundation
import Promise
import Base
import Database
import Networking

func scheduleTaskTimer() -> DispatchSourceTimer {
    let queue = DispatchQueue(label: "Scheduled Task Timer")
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: 120.0, leeway: .seconds(1))
    timer.setEventHandler {
        tryOrLog {
            let conn = postgres.lazyConnection()
            func process(_ tasks: ArraySlice<Row<TaskData>>) {
                guard let task = tasks.first else { return }
                try? task.process(conn) { _ in
                    process(tasks.dropFirst())
                }
            }
            let tasks = try conn.get().execute(Row<TaskData>.dueTasks)
            process(tasks[...])
        }
    }
    timer.resume()
    return timer
}

enum Task {
    case syncTeamMembersWithRecurly(userId: UUID)
    case releaseEpisode(number: Int)
    case unfinishedSubscriptionReminder(userId: UUID)
}

struct TaskError: Error {
    var message: String
}

extension Task: Codable {
    enum CodingKeys: CodingKey {
        case syncTeamMembersWithRecurly
        case releaseEpisode
        case unfinishedSubscriptionReminder
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .syncTeamMembersWithRecurly(let userId):
            try container.encode(userId, forKey: .syncTeamMembersWithRecurly)
        case .releaseEpisode(let number):
            try container.encode(number, forKey: .releaseEpisode)
        case .unfinishedSubscriptionReminder(let userId):
            try container.encode(userId, forKey: .unfinishedSubscriptionReminder)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decode(UUID.self, forKey: .syncTeamMembersWithRecurly) {
            self = .syncTeamMembersWithRecurly(userId: id)
        } else if let number = try? container.decode(Int.self, forKey: .releaseEpisode) {
            self = .releaseEpisode(number: number)
        } else if let id = try? container.decode(UUID.self, forKey: .unfinishedSubscriptionReminder) {
            self = .unfinishedSubscriptionReminder(userId: id)
        } else {
            throw TaskError(message: "Unable to decode")
        }
    }
    
    func uniqueKey(for date: Date) -> String {
        switch self {
        case .syncTeamMembersWithRecurly(let userId):
            return "\(CodingKeys.syncTeamMembersWithRecurly.stringValue):\(userId.uuidString)"
        case .releaseEpisode(let number):
            return "\(CodingKeys.releaseEpisode.stringValue):\(number)"
        case .unfinishedSubscriptionReminder(let userId):
            return "\(CodingKeys.unfinishedSubscriptionReminder.stringValue):\(userId.uuidString)"
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

    static var tableName: TableName = "tasks"
}

extension Task {
    func schedule(at date: Date) -> Query<()> {
        let taskData = TaskData(date: date, task: self)
        return taskData.insertOrUpdate(uniqueKey: "key").map { _ in }
    }

    func schedule(minutes: Int) -> Query<()> {
        let date = globals.currentDate().addingTimeInterval(60 * TimeInterval(minutes))
        return schedule(at: date)
    }

    func schedule(weeks: Int) -> Query<()> {
        let date = Calendar.current.date(byAdding: DateComponents(day: weeks * 7), to: globals.currentDate())!
        return schedule(at: date)
    }
    
    func interpret(_ c: Lazy<ConnectionProtocol>, onCompletion: @escaping (Bool) -> ()) throws {
        switch self {
        case .syncTeamMembersWithRecurly(let userId):
            guard let user = try c.get().execute(Row<UserData>.select(userId)) else { onCompletion(true); return }            
            let memberCount = try c.get().execute(user.teamMemberCountForRecurly)
            globals.urlSession.load(user.updateCurrentSubscription(numberOfTeamMembers: memberCount), onComplete: { sub in
                guard let s = try? sub.get() else { onCompletion(false); return }
                onCompletion((s.subscription_add_ons?.first?.quantity ?? 0) == memberCount)
            })
        
        case .releaseEpisode(let number):
            if mailchimp.apiKey == "test" { onCompletion(true); return } // don't release episodes in test environments
            guard let ep = Episode.all.first(where: { $0.number == number }) else { onCompletion(true); return }
            let sendCampaign: Promise<Bool> = globals.urlSession.load(mailchimp.createCampaign(for: ep)).flatMap { campaignId in
                guard let id = campaignId else { return Promise { $0(false) } }
                return globals.urlSession.load(mailchimp.addContent(for: ep, toCampaign: id)).flatMap { _ in
                    if env.production {
                        return globals.urlSession.load(mailchimp.sendCampaign(campaignId: id)).map { $0 != nil }
                    } else {
                        return globals.urlSession.load(mailchimp.testCampaign(campaignId: id)).map { $0 != nil }
                    }
                }
            }

            globals.urlSession.load(github.changeVisibility(private: false, of: ep.id.rawValue)).flatMap { _ in
                globals.urlSession.load(circle.triggerMainSiteBuild)
            }.flatMap { _ in
                globals.urlSession.load(mailchimp.existsCampaign(for: ep))
            }.flatMap { campaignExists in
                return campaignExists == false ? sendCampaign : Promise { $0(false) }
            }.run { success in
                onCompletion(success)
            }
        
        case .unfinishedSubscriptionReminder(let userId):
            guard let user = try c.get().execute(Row<UserData>.select(userId)), !user.data.subscriber else { onCompletion(true); return }
            let ep = sendgrid.send(to: user.data.email, name: user.data.name, subject: "Your Swift Talk Registration", text: unfinishedSubscriptionReminderText)
            globals.urlSession.load(ep) { onCompletion($0 != nil)}
        }
    }
}

extension Row where Element == TaskData {
    func process(_ c: Lazy<ConnectionProtocol>, onCompletion: @escaping (Bool) -> ()) throws {
        let task = try JSONDecoder().decode(Task.self, from: self.data.json.data(using: .utf8)!)
        try task.interpret(c) { success in
            if success {
                tryOrLog("Failed to delete task \(self.id) from database") { try c.get().execute(self.delete) }
            }
            onCompletion(success)
        }
    }
}

fileprivate let unfinishedSubscriptionReminderText = """
Hi!

We noticed that you signed up for Swift Talk a while ago, but never finished your registration. We'd love for you to become a subscriber.

Use the following link to get a 20% discount: https://talk.objc.io/promo/swift-talk-discount (you'll get 20% off of the first three months, or if you choose a yearly plan, 20% off of your first year).

If you have any questions, let us know.

Best from Berlin,
Florian and Chris
"""
