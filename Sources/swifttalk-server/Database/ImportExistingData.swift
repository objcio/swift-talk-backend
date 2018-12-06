//
//  ImportExistingData.swift
//  Bits
//
//  Created by Chris Eidhof on 04.12.18.
//

import Foundation


fileprivate let formatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    return dateFormatter
}()

struct ImportEpisode: Codable {
    var id: UUID
    var number: Int
}

struct ImportUser: Codable {
    var id: UUID
    var email: String?
    var github_uid: Int
    var github_login: String
    var github_token: String?
    var avatar_url: String?
    var name: String?
    var remember_created_at: Date?
//    var sign_in_count|integer||not null|0|plain||
//    var current_sign_in_at|timestamp without time zone||||plain||
//    var last_sign_in_at|timestamp without time zone||||plain||
 //   var current_sign_in_ip|inet||||main||
//    var last_sign_in_ip|inet||||main||
    var admin: Bool
    var created_at: Date?
    var updated_at: Date?
    var recurly_hosted_login_token: String?
//    var payment_method_id|uuid||||plain||
    var last_reconciled_at: Date?
//    var receive_new_episode_emails|boolean|||true|plain||
    var collaborator: Bool?
    var download_credits: Int
//	var confirmed
}

struct ImportDownload: Codable {
    var id: UUID
    var user_id: UUID
    var episode_id: UUID
    var created_at: Date
    var updated_at: Date
}

struct ImportTeamMember: Codable {
    var id: UUID
    var owner_id: UUID
    var user_id: UUID
    var created_at: Date
    var updated_at: Date
}

struct ImportView: Codable {
    var id: UUID
    var episode_id: UUID
    var user_id: UUID?
    var play_count: Int
    var last_played_at: Date
    var furthest_watched: Int
    var play_position: Int
    var created_at: Date
    var updated_at: Date
}

func decode<A: Decodable>(_ file: String) throws -> [A] {
    let dec = JSONDecoder()
    if #available(OSX 10.12, *) {
        dec.dateDecodingStrategy = .formatted(formatter)
    }
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(file)
    let data = try Data(contentsOf: url)
    return try dec.decode([A].self, from: data)
}

func importExistingData() throws {
    _ = try withConnection { conn in
        try conn.execute("DELETE FROM sessions")
        try conn.execute("DELETE FROM downloads")
        try conn.execute("DELETE FROM team_members")
        try conn.execute("DELETE FROM play_progress")
        try conn.execute("DELETE FROM users")
        let users: [ImportUser] = try decode("data/users.json")
        print(users.count)

        let downloads: [ImportDownload] = try decode("data/downloads.json")
        print(downloads.count)

        let teamMembers: [ImportTeamMember] = try decode("data/team_member_associations.json")
        print(teamMembers.count)

        let views: [ImportView] = try decode("data/episode_views.json")
        print(views.count)

        let eps: [ImportEpisode] = try decode("data/episodes.json")
        let epMap: [UUID:Int] = Dictionary(eps.map { ($0.id, $0.number) }, uniquingKeysWith: { $1 })

        var duplicates: [UUID:UUID] = [:]
        for u in users {
//            guard let email = u.email else {
////                print("skipping ", u.name, u.github_login)
//                assert(u.last_reconciled_at == nil)
//                continue
//            }
            let userData = UserData(email: u.email ?? "none", githubUID: u.github_uid, githubLogin: u.github_login, githubToken: u.github_token, avatarURL: u.avatar_url ?? "", name: u.name ?? "", createdAt: u.created_at, rememberCreatedAt: u.remember_created_at, updatedAt: u.updated_at, collaborator: u.collaborator ?? false, downloadCredits: u.download_credits, canceled: false, confirmedNameAndEmail: true)
            do {
		try conn.execute(userData.insertFromImport(id: u.id))
            } catch {
                let other = try conn.execute(Row<UserData>.select(githubLogin: u.github_login))
                duplicates[u.id] = other!.id
//                dump(other!)
//                dump(userData)
////                try conn.execute(userData.insertOrUpdate(uniqueKey: "github_uid"))
//                print(error)
            }
        }

        for t in teamMembers {
//            let owner = try conn.execute(Row<UserData>.select(t.owner_id))
            let data = TeamMemberData(userId: t.owner_id, teamMemberId: t.user_id)
            do {
		let id = try conn.execute(data.insert)
            } catch {
                dump(data)
                dump(duplicates)
                print(error)
//                fatalError()
            }
        }

        var failure = 1
        for d in downloads {
            guard let number = epMap[d.episode_id] else {
                let u = try conn.execute(Row<UserData>.select(duplicates[d.user_id] ?? d.user_id))
                print("download \(d.episode_id) for non-existing episode... \(d.episode_id) \(u?.data.name)")
                failure += 1
                continue
            }
            let data = DownloadData(user: duplicates[d.user_id] ?? d.user_id, episode: number)
            do {
                try conn.execute(data.insert)
            } catch {
                let u = try conn.execute(Row<UserData>.select(d.user_id))
                failure += 1
                if u == nil {
			print("no user", data.episodeNumber, d.user_id, duplicates)
                } else {
                    print("double download", data.episodeNumber, u!.data.name)
                }
//                dump(u)
            }
        }
        print("download failures: \(failure)")

        for v in views {
            guard let i = v.user_id else {
//                print("skipping", v)
                continue
            }
            guard let num = epMap[v.episode_id] else {
                print("no such episode \(v.episode_id)")
                continue
            }
            let d = PlayProgressData.init(userId: duplicates[i] ?? i, episodeNumber: num, progress: v.play_position, furthestWatched: v.furthest_watched)
            do {
                _ = try conn.execute(d.insert, loggingTreshold: 0.4)
            } catch {
                print(error)
            }
        }
        log(info: "Migration Done")

//            fatalError("Done")
    }
}
