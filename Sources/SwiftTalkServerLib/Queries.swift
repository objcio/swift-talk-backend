//
//  Queries.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation
import Database
import LibPQ


extension Database.Row where Element == FileData {
    static func select(key: String) -> Query<Database.Row<FileData>?> {
        return selectOne.appending(parameters: [key]) { "WHERE key=\($0[0])" }
    }
    
    static func select(repository: String, path: String) -> Query<Database.Row<FileData>?> {
        return select(key: FileData.key(forRepository: repository, path: path))
    }
    
    static func transcripts() -> Query<[Database.Row<FileData>]> {
        return select.appending(parameters: [FileData.keyPrefix(forRepository: github.transcriptsRepo)]) {
            "WHERE key LIKE \($0[0]) || '%'"
        }
    }
    
    static func staticData(jsonName: String) -> Query<Database.Row<FileData>?> {
        let key = FileData.key(forRepository: github.staticDataRepo, path: jsonName)
        return selectOne.appending(parameters: [key]) { "WHERE key=\($0[0])" }
    }
}

extension Database.Row where Element == GiftData {
    static func select(subscriptionId id: String) -> Query<Database.Row<Element>?> {
        return Database.Row<GiftData>.selectOne.appending(parameters: [id]) { "WHERE subscription_id=\($0[0])" }
    }
}

extension Database.Row where Element == UserData {
    static func select(githubId id: Int) -> Query<Database.Row<Element>?> {
        return Database.Row<UserData>.selectOne.appending(parameters: [id]) { "WHERE github_uid=\($0[0])" }
    }
    
    static func select(githubLogin login: String) -> Query<Database.Row<Element>?> {
        return Database.Row<UserData>.selectOne.appending(parameters: [login]) { "WHERE github_login=\($0[0])" }
    }

    static func select(teamToken: UUID) -> Query<Database.Row<Element>?> {
        return Database.Row<UserData>.selectOne.appending(parameters: [teamToken]) { "WHERE team_token=\($0[0])" }
    }

    static func select(sessionId id: UUID) -> Query<Database.Row<Element>?> {
        let fields = UserData.fieldList { "u.\($0)" }
        return .build(parameters: [id], parse: Element.parseFirst) {
            "SELECT u.id,\(fields) FROM \(UserData.tableName) AS u INNER JOIN \(SessionData.tableName) AS s ON s.user_id = u.id WHERE s.id=\($0[0])"
        }
    }
    
    var teamMember: Query<Database.Row<TeamMemberData>?> {
        let fields = TeamMemberData.fieldList { "tm.\($0)" }
        return .build(parameters: [id], parse: TeamMemberData.parseFirst) { """
            SELECT tm.id,\(fields) FROM \(TeamMemberData.tableName) AS tm
            INNER JOIN \(UserData.tableName) AS u ON tm.user_id = u.id
            WHERE tm.team_member_id=\($0[0]) AND tm.expired_at IS NULL AND u.subscriber=true
            ORDER BY tm.created_at ASC
            """
        }
    }

    var gifter: Query<Database.Row<UserData>?> {
        let fields = UserData.fieldList { "u.\($0)" }
        return .build(parameters: [id], parse: Element.parseFirst) { """
            SELECT u.id,\(fields) FROM \(UserData.tableName) AS u
            INNER JOIN \(GiftData.tableName) AS g ON g.gifter_user_id = u.id
            WHERE g.giftee_user_id=\($0[0]) AND u.subscriber=true
            """
        }
    }
    
    var downloads: Query<[Database.Row<DownloadData>]> {
        return Database.Row<DownloadData>.select.appending(parameters: [id]) { "WHERE user_id=\($0[0])" }
    }
    
    var teamMembers: Query<[Database.Row<UserData>]> {
        let fields = UserData.fieldList { "u.\($0)" }
        return .build(parameters: [id], parse: Element.parse) { """
            SELECT u.id,\(fields) FROM \(UserData.tableName) AS u
            INNER JOIN \(TeamMemberData.tableName) AS t ON t.team_member_id = u.id
            WHERE t.user_id=\($0[0]) AND t.expired_at IS NULL
            """
        }
    }
    
    func deleteSession(_ sessionId: UUID) -> Query<()> {
        return Database.Row<SessionData>.delete.appending(parameters: [id, sessionId]) { "WHERE user_id=\($0[0]) AND id=\($0[1])" }
    }
    
    func changeSubscriptionStatus(_ subscribed: Bool) -> Query<()> {
        return .build(parameters: [subscribed, id], parse: Element.parseEmpty) { "UPDATE users SET subscriber=\($0[0]) WHERE id=\($0[1])" }
    }
    
    func deleteTeamMember(teamMemberId: UUID, userId: UUID) -> Query<()> {
        return Query.build(parameters: [teamMemberId, userId], parse: Element.parseEmpty) { """
            UPDATE \(TeamMemberData.tableName) SET expired_at=LOCALTIMESTAMP
            WHERE team_member_id=\($0[0]) AND user_id=\($0[1]) AND expired_at IS NULL
            """
        }
    }
    
    var teamMemberCountForRecurly: Query<Int> {
        return teamMembers.map { teamMembers in
            return self.data.role == .teamManager ? teamMembers.count - 1 : teamMembers.count
        }
    }
}

extension Database.Row where Element == TaskData {
    static var dueTasks: Query<[Database.Row<TaskData>]> {
        return Database.Row<TaskData>.select.appending() { _ in "WHERE date < LOCALTIMESTAMP ORDER BY date ASC" }
    }
}

extension Database.Row where Element == PlayProgressData {
    static func sortedDesc(for userId: UUID) -> Query<[Database.Row<PlayProgressData>]> {
        return Database.Row<PlayProgressData>.select.appending(parameters: [userId]) { "WHERE user_id=\($0[0]) ORDER BY episode_number DESC" }
    }
}
