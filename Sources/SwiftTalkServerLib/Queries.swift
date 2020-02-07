//
//  Queries.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation
import Database


extension Database.Row where Element == FileData {
    static func select(key: String) -> Query<Database.Row<FileData>?> {
        return selectOne.appending("WHERE key=\(param: key)")
    }
    
    static func select(repository: String, path: String) -> Query<Database.Row<FileData>?> {
        return select(key: FileData.key(forRepository: repository, path: path))
    }
    
    static func transcripts() -> Query<[Database.Row<FileData>]> {
        return select.appending(
            "WHERE key LIKE \(param: FileData.keyPrefix(forRepository: github.transcriptsRepo)) || '%'"
        )
    }
    
    static func staticData(jsonName: String) -> Query<Database.Row<FileData>?> {
        let key = FileData.key(forRepository: github.staticDataRepo, path: jsonName)
        return selectOne.appending("WHERE key=\(param: key)")
    }
}

extension Database.Row where Element == GiftData {
    static func select(subscriptionId id: String) -> Query<Database.Row<Element>?> {
        return Database.Row<GiftData>.selectOne.appending("WHERE subscription_id=\(param: id)")
    }
}

extension Database.Row where Element == UserData {
    static func select(githubId id: Int) -> Query<Database.Row<Element>?> {
        return Database.Row<UserData>.selectOne.appending("WHERE github_uid=\(param: id)")
    }
    
    static func select(githubLogin login: String) -> Query<Database.Row<Element>?> {
        return Database.Row<UserData>.selectOne.appending("WHERE github_login=\(param: login)")
    }

    static func select(teamToken: UUID) -> Query<Database.Row<Element>?> {
        return Database.Row<UserData>.selectOne.appending("WHERE team_token=\(param: teamToken)")
    }

    static func select(sessionId id: UUID) -> Query<Database.Row<Element>?> {
        let fields = UserData.fieldList { "u.\($0)" }
        return Query("SELECT u.id,\(raw: fields) FROM \(UserData.tableName) AS u INNER JOIN \(SessionData.tableName) AS s ON s.user_id = u.id WHERE s.id=\(param: id)", parse: Element.parseFirst)
    }
    
    var teamMember: Query<Database.Row<TeamMemberData>?> {
        let fields = TeamMemberData.fieldList { "tm.\($0)" }
        return Query("""
            SELECT tm.id,\(raw: fields) FROM \(TeamMemberData.tableName) AS tm
            INNER JOIN \(UserData.tableName) AS u ON tm.user_id = u.id
            WHERE tm.team_member_id=\(param: id) AND tm.expired_at IS NULL AND u.subscriber=true
            ORDER BY tm.created_at ASC
            """, parse: TeamMemberData.parseFirst)
    }

    var gifter: Query<Database.Row<UserData>?> {
        let fields = UserData.fieldList { "u.\($0)" }
        return Query("""
            SELECT u.id,\(raw: fields) FROM \(UserData.tableName) AS u
            INNER JOIN \(GiftData.tableName) AS g ON g.gifter_user_id = u.id
            WHERE g.giftee_user_id=\(param: id) AND u.subscriber=true
            """, parse: Element.parseFirst)
    }
    
    var downloads: Query<[Database.Row<DownloadData>]> {
        return Database.Row<DownloadData>.select.appending("WHERE user_id=\(param: id)")
    }
    
    var teamMembers: Query<[Database.Row<UserData>]> {
        let fields = UserData.fieldList { "u.\($0)" }
        return Query("""
            SELECT u.id,\(raw: fields) FROM \(UserData.tableName) AS u
            INNER JOIN \(TeamMemberData.tableName) AS t ON t.team_member_id = u.id
            WHERE t.user_id=\(param: id) AND t.expired_at IS NULL
            """, parse: Element.parse)
    }
    
    func deleteSession(_ sessionId: UUID) -> Query<()> {
        return Database.Row<SessionData>.delete.appending("WHERE user_id=\(param: id) AND id=\(param: sessionId)")
    }
    
    func changeSubscriptionStatus(_ subscribed: Bool) -> Query<()> {
        return Query("UPDATE users SET subscriber=\(param: subscribed) WHERE id=\(param: id)", parse: Element.parseEmpty)
    }
    
    func deleteTeamMember(teamMemberId: UUID, userId: UUID) -> Query<()> {
        let q: QueryStringAndParams = "UPDATE \(TeamMemberData.tableName) SET expired_at=LOCALTIMESTAMP WHERE team_member_id=\(param: teamMemberId) AND user_id=\(param: userId) AND expired_at IS NULL"
        return Query(q
        , parse: Element.parseEmpty)
    }
    
    // todo: this might return -1 when there's a team manager and teamMembers.count = 0. 
    var teamMemberCountForRecurly: Query<Int> {
        return teamMembers.map { teamMembers in
            return self.data.role == .teamManager ? teamMembers.count - 1 : teamMembers.count
        }
    }
}

extension Database.Row where Element == TaskData {
    static var dueTasks: Query<[Database.Row<TaskData>]> {
        return Database.Row<TaskData>.select.appending("WHERE date < LOCALTIMESTAMP AND failed=false ORDER BY date ASC")
    }
    
    static var all: Query<[Database.Row<TaskData>]> {
        return Database.Row<TaskData>.select.appending("ORDER BY date ASC")
    }
}

extension Database.Row where Element == PlayProgressData {
    static func sortedDesc(for userId: UUID) -> Query<[Database.Row<PlayProgressData>]> {
        return Database.Row<PlayProgressData>.select.appending("WHERE user_id=\(param: userId) ORDER BY episode_number DESC")
    }
}
