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
        return (selfPremiumAccess && !user.data.canceled) ||
            (gifterPremiumAccess && gifter?.data.canceled == false) ||
            (teamMemberPremiumAccess && masterTeamUser?.data.canceled == false)
    }
    
    var teamMemberPremiumAccess: Bool {
        return masterTeamUser?.data.premiumAccess == true
    }
    
    var gifterPremiumAccess: Bool {
        return gifter?.data.premiumAccess == true
    }
    
    var selfPremiumAccess: Bool {
        return user.data.premiumAccess
    }
}
