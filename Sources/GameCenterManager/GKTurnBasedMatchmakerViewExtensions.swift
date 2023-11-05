//
//  GKTurnBasedMatchmakerViewExtensions.swift
//  Hexo
//
//  Created by Kevin Mullins on 10/3/23.
//

import Foundation
import SwiftUI
import SwiftletUtilities
import GameKitUI
import GameKit

extension GKTurnBasedMatchmakerView {
    
    /// Creates a new instance of the `GKTurnBasedMatchmakerView`
    /// - Parameters:
    ///   - minPlayers: The minimum number of players.
    ///   - maxPlayers: The maximum number of players.
    ///   - playerGroup: The player grooup.
    ///   - inviteMessage: The game start invitation message.
    ///   - canceled: Handle the matchmaking being canceled.
    ///   - failed: Handle the matchmaking failing.
    ///   - started: Handle the matchmaking starting.
    public init(minPlayers: Int,
                maxPlayers: Int,
                playerGroup: Int,
                inviteMessage: String,
                canceled: @escaping () -> Void,
                failed: @escaping (Error) -> Void,
                started: @escaping (GKTurnBasedMatch) -> Void) {
        let matchRequest = GKMatchRequest()
        matchRequest.minPlayers = minPlayers
        matchRequest.maxPlayers = maxPlayers
        matchRequest.playerGroup = playerGroup
        matchRequest.inviteMessage = inviteMessage
        self.init(matchRequest: matchRequest, canceled: canceled, failed: failed, started: started)
    }
    
}


