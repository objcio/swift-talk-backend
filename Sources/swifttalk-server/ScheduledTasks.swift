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
}

struct TaskError: Error {
    var message: String
}

extension Task: Codable {
    enum CodingKeys: CodingKey {
        case syncTeamMembersWithRecurly
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .syncTeamMembersWithRecurly(let userId):
            try container.encode(userId, forKey: .syncTeamMembersWithRecurly)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decode(UUID.self, forKey: .syncTeamMembersWithRecurly) {
            self = .syncTeamMembersWithRecurly(userId: id)
        }
        throw TaskError(message: "Unable to decode")
    }
}

struct TaskData: Insertable {
    var date: Date
    var json: String

    static var tableName = "tasks"
}

extension Task {
    func schedule(at date: Date) throws -> Query<()> {
        let data = try JSONEncoder().encode(self)
        let json = String(data: data, encoding: .utf8)!
        let taskData = TaskData(date: date, json: json)
        return taskData.insert.map { _ in }
    }
    
    func interpret(_ c: Lazy<Connection>) throws {
        switch self {
        case .syncTeamMembersWithRecurly(let userId):
            guard let user = try c.get().execute(Row<UserData>.select(userId)) else { return }
            let teamMembers = try c.get().execute(user.teamMembers)
            let currentCount = teamMembers.count
            // TODO update addon count with recurly
        }
    }
}

extension Row where Element == TaskData {
    func process(_ c: Lazy<Connection>) throws {
        let task = try JSONDecoder().decode(Task.self, from: self.data.json.data(using: .utf8)!)
        try task.interpret(c)
        try c.get().execute(self.delete)
    }
}
