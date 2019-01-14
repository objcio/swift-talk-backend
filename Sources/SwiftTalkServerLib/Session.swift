//
//  Session.swift
//  Bits
//
//  Created by Chris Eidhof on 14.12.18.
//

import Foundation

struct Context {
    var route: Route
    var message: (String, FlashType)?
    var session: Session?
    
    var csrf: CSRFToken {
        return session?.user.data.csrf ?? sharedCSRF
    }
}

struct Session {
    var sessionId: UUID
    var user: Row<UserData>
    var masterTeamUser: Row<UserData>?
    var gifter: Row<UserData>?
    
    var premiumAccess: Bool {
        return selfPremiumAccess || teamMemberPremiumAccess || gifterPremiumAccess
    }
    
    var activeSubscription: Bool {
        return ((selfPremiumAccess || user.data.subscriber) && !user.data.canceled) ||
            (gifterPremiumAccess && gifter?.data.canceled == false) ||
            (teamMemberPremiumAccess && masterTeamUser?.data.canceled == false)
    }
    
    var teamMemberPremiumAccess: Bool {
        return masterTeamUser?.data.subscriber == true
    }
    
    var gifterPremiumAccess: Bool {
        return gifter?.data.premiumAccess == true
    }
    
    var selfPremiumAccess: Bool {
        return user.data.premiumAccess
    }

    func downloadStatus(for episode: Episode, downloads: [Row<DownloadData>]) -> Episode.DownloadStatus {
        guard premiumAccess else { return .notSubscribed }
        let creditsLeft = (user.data.downloadCredits + user.data.downloadCreditsOffset) - downloads.count
        if user.data.isAdmin || downloads.contains(where: { $0.data.episodeNumber == episode.number }) {
            return .reDownload
        } else if creditsLeft > 0 {
            return .canDownload(creditsLeft: creditsLeft)
        } else {
            return .noCredits
        }
    }
}
