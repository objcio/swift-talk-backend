//
//  Session.swift
//  Bits
//
//  Created by Chris Eidhof on 14.12.18.
//

import Foundation
import Database
import WebServer


typealias STRequestEnvironment = RequestEnvironment<Route, Session>
typealias STContext = Context<Route, Session>

public struct Session {
    var sessionId: UUID
    var user: Row<UserData>
    private var teamMember: Row<TeamMemberData>?
    private var teamManager: Row<UserData>?
    private var gifter: Row<UserData>?
    
    init(sessionId: UUID, user: Row<UserData>, teamMember: Row<TeamMemberData>?, teamManager: Row<UserData>?, gifter: Row<UserData>?) {
        self.sessionId = sessionId
        self.user = user
        self.teamMember = teamMember
        self.teamManager = teamManager
        self.gifter = gifter
    }
    
    var premiumAccess: Bool {
        return selfPremiumAccess || teamMemberPremiumAccess || gifterPremiumAccess
    }
    
    var activeSubscription: Bool {
        return ((selfPremiumAccess || user.data.subscriber) && !user.data.canceled) ||
            (gifterPremiumAccess && gifter?.data.canceled == false) ||
            (teamMemberPremiumAccess && teamManager?.data.canceled == false)
    }
    
    var teamMemberPremiumAccess: Bool {
        return teamManager?.data.subscriber == true
    }
    
    var gifterPremiumAccess: Bool {
        return gifter?.data.premiumAccess == true
    }
    
    var selfPremiumAccess: Bool {
        return user.data.premiumAccess
    }
    
    func isTeamMemberOf(_ user: Row<UserData>) -> Bool {
        return teamManager?.id == user.id
    }
    
    var downloadCredits: Int {
        if selfPremiumAccess {
            return user.data.downloadCredits
        } else if gifterPremiumAccess, let g = gifter {
            return g.data.downloadCredits
        } else if teamMemberPremiumAccess, let tm = teamMember {
            return tm.data.activeMonths * 4
        }
        return 0
    }

    func downloadStatus(for episode: Episode, downloads: [Row<DownloadData>]) -> Episode.DownloadStatus {
        guard premiumAccess else { return user.data.role == .teamManager ? .teamManager : .notSubscribed }
        let creditsLeft = (downloadCredits + user.data.downloadCreditsOffset) - downloads.count
        if user.data.isAdmin || downloads.contains(where: { $0.data.episodeNumber == episode.number }) {
            return .reDownload
        } else if creditsLeft > 0 {
            return .canDownload(creditsLeft: creditsLeft)
        } else {
            return .noCredits
        }
    }
}


extension Session: SessionP {
    public var csrf: CSRFToken {
        return user.data.csrfToken
    }
}
