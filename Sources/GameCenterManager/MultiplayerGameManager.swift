//
//  MultiplayerGameManager.swift
//  Hexo
//
//  Created by Kevin Mullins on 9/30/23.
//

import Foundation
import GameKit
import SwiftUI
import SwiftletUtilities
import LogManager

/// Handles all communication between the players and a Turn Based Game Center Multiplayer Match.
/// - Remark: WARNING! You mus use the Player's `displayName` to identify them and NOT the `teamPlayerID`, as it seems to change from invocation to invocation of the game.
open class MultiplayerGameManager:NSObject, GKLocalPlayerListener {
    public typealias LoadGameDataCompletionHandler = (Bool) -> Void
    
    // MARK: - Static Computed Properties
    /// Returns `true` if it is the local player's turn, else it returns `false`.
    public static var isLocalPlayersTurn:Bool {
        guard let match = GameCenterManager.shared.currentMatch else {
            return false
        }
        
        return (GKLocalPlayer.local.displayName == match.currentParticipant?.player?.displayName)
    }
    
    // MARK: - Static Functions
    /// Sends the given status update to all players in the game.
    public static func sendStatusUpdate() {
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return
        }
        
        // Ensure an encoder was attached.
        guard let encoder = GameCenterManager.shared.gameStateEncoder else {
            return
        }
        
        // Convert game to data
        let data: Data? = encoder()
        
        // Send new game to other players
        if let data = data {
            match.saveCurrentTurn(withMatch: data, completionHandler: {error in
                if let error = error {
                    Log.error(subsystem: "Multiplayer Game Manager", category: "sendStatusUpdate", "Saving match data error: \(error)")
                }
            })
        }
    }
    
    /// Gets the list of the next players in the game.
    /// - Returns: The list of the next players in the game.
    public static func getNextPlayerList() -> [GKTurnBasedParticipant] {
        var list:[GKTurnBasedParticipant] = []
        var before:[GKTurnBasedParticipant] = []
        var curent:GKTurnBasedParticipant? = nil
        var after:[GKTurnBasedParticipant] = []
        let displayName = GKLocalPlayer.local.displayName
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return list
        }
        
        for participant in match.participants {
            switch(participant.status) {
            case .active, .matching, .invited:
                if curent == nil && participant.player?.displayName != displayName {
                    before.append(participant)
                } else if participant.player?.displayName == displayName {
                    curent = participant
                } else {
                    after.append(participant)
                }
            default:
                break
            }
        }
        
        // Assemble new list
        if after.count > 0 {
            list.append(contentsOf: after)
        }
        
        if before.count > 0 {
            list.append(contentsOf: before)
        }
        
        if let curent = curent {
            list.append(curent)
        }
        
        // Return resulting list
        return list
    }
    
    /// Ends the current player's turn.
    public static func endTurn() {
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return
        }
        
        // Ensure an encoder was attached.
        guard let encoder = GameCenterManager.shared.gameStateEncoder else {
            return
        }
        
        // Update current player's status
        if let handler = GameCenterManager.shared.playerTurnEnd {
            handler(GKLocalPlayer.local)
        }
        
        // Get players that are next to play
        let players = getNextPlayerList()
        
        // Convert game to data
        let data: Data? = encoder()
        
        // Send new game to other players
        if let data = data {
            match.endTurn(withNextParticipants: players, turnTimeout: GKExchangeTimeoutDefault, match: data, completionHandler: {error in
                if let error = error {
                    Log.error(subsystem: "Multiplayer Game Manager", category: "endTurn", "Saving match data error: \(error)")
                }
            })
        }
    }
    
    /// Allows a given player to quit the game when is their turn to play.
    /// - Parameters:
    ///   - outcome: The outcome of the player quitting the game.
    ///   - displayName: The unique ID of the player that has quit.
    public static func quitInTurn(outcome:GKTurnBasedMatch.Outcome, displayName:String = GKLocalPlayer.local.displayName) {
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return
        }
        
        // Ensure an encoder was attached.
        guard let encoder = GameCenterManager.shared.gameStateEncoder else {
            return
        }
        
        // Update current player's status
        if let handler = GameCenterManager.shared.playerQuitInTurn {
            handler(GKLocalPlayer.local)
        }
        
        // Get players that are next to play
        let players = getNextPlayerList()
        
        // Convert game to data
        let data: Data? = encoder()
        
        // Send new game to other players
        if let data = data {
            match.participantQuitInTurn(with: outcome, nextParticipants: players, turnTimeout: GKExchangeTimeoutDefault, match: data, completionHandler: {error in
                if let error = error {
                    Log.error(subsystem: "Multiplayer Game Manager", category: "quitInTurn", "Saving match data error: \(error)")
                }
            })
        }
        
        // End the match if there are no more players
        endMatchIfNoMorePlayers()
    }
    
    /// Allows the given player to quit the game outside of their turn.
    /// - Parameter displayName: The unique ID of the player that has quit.
    public static func quitOutOfTurn(displayName:String = GKLocalPlayer.local.displayName) {
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return
        }
        
        // Update current player's status
        if let handler = GameCenterManager.shared.playerQuitOutOfTurn {
            handler(GKLocalPlayer.local)
        }
        
        // Send new game to other players
        match.participantQuitOutOfTurn(with: .quit, withCompletionHandler:  {error in
            if let error = error {
                Log.error(subsystem: "Multiplayer Game Manager", category: "quitOutOfTurn", "Saving match data error: \(error)")
            }
        })
    }
    
    /// Makers the given player as having quit the game.
    /// - Parameter displayName: The unique ID of the player that quit.
    public static func markCurrentPlayerQuit(_ displayName:String = GKLocalPlayer.local.displayName) {
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return
        }
        
        // Let match know the player won
        for participant in match.participants {
            switch(participant.status) {
            case .active, .matching, .invited:
                if participant.player?.displayName == displayName {
                    participant.matchOutcome = .quit
                }
            default:
                break
            }
        }
    }
    
    /// Gets the `GKPlayer` for the given `displayName`.
    /// - Parameter displayName: The unique ID of the player to locate.
    /// - Returns: Returns the requested `GKPlayer` or `nil` if the player isn't found.
    public static func getGameCenterPlayer(for displayName:String) -> GKPlayer? {
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return nil
        }
        
        // Scan for player
        for participant in match.participants {
            if participant.player?.displayName == displayName {
                return participant.player
            }
        }
        
        return nil
    }
    
    /// Saves the score for the given player to the leads boards for the game based on the game type.
    /// - Parameters:
    ///   - score: The score to save.
    ///   - player: The `GKPlayer` to save the score to.
    ///   - leaderBoards: A list of leaderboards to record the score to.
    public static func savePlayerScore(of score:Int, for player:GKPlayer, leaderBoards:[String]) {
        
        // Send as individual scores.
        for board in leaderBoards {
            GKLeaderboard.submitScore(score, context: 1, player: player, leaderboardIDs: [board], completionHandler: {error in
                if let error = error {
                    Log.error(subsystem: "Multiplayer Game Manager", category: "savePlayerScore", "Error saving score to \(board): \(error)")
                } else {
                    Debug.info(subsystem: "Multiplayer Game Manager", category: "savePlayerScore", "Score of \(score) saved successfully to \(board).")
                }
            })
        }
    }
    
    /// Tells Game Center that the given player has won the game.
    /// - Parameter displayName: The unique ID of the player that won the game.
    public static func wonGame(displayName:String) {
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return
        }
        
        // Ensure an encoder was attached.
        guard let encoder = GameCenterManager.shared.gameStateEncoder else {
            return
        }
        
        // Update current player's status
        if let handler = GameCenterManager.shared.playerWonGame {
            handler(GKLocalPlayer.local)
        }
        
        // Let match know the player won
        for participant in match.participants {
            switch(participant.status) {
            case .active, .matching, .invited:
                if participant.player?.displayName == displayName {
                    participant.matchOutcome = .won
                } else {
                    participant.matchOutcome = .lost
                    
                    // Update other player's status
                    if let id = participant.player?.displayName {
                        if let handler = GameCenterManager.shared.playerLostGame {
                            handler(id)
                        }
                    }
                }
            default:
                break
            }
        }
        
        // Send status update to other players that the game is over
        if let handler = GameCenterManager.shared.gameEnded {
            handler()
        }
        
        // Convert game to data
        let data: Data? = encoder()
        
        // Send new game to other players
        if let data = data {
            match.endMatchInTurn(withMatch: data, completionHandler: {error in
                if let error = error {
                    Log.error(subsystem: "Multiplayer Game Manager", category: "wonGame", "Saving match data error: \(error)")
                }
            })
        }
    }
    
    /// Tell Game Center that the player lost the game
    public static func lostGame() {
        
        let displayName = GKLocalPlayer.local.displayName
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return
        }
        
        // Ensure an encoder was attached.
        guard let encoder = GameCenterManager.shared.gameStateEncoder else {
            return
        }
        
        // Update current player's status
        if let handler = GameCenterManager.shared.playerLostGame {
            handler(displayName)
        }
        
        // Let match know the player lost
        for participant in match.participants {
            if participant.player?.displayName == displayName {
                participant.matchOutcome = .lost
            }
        }
        
        // Get players that are next to play
        let players = getNextPlayerList()
        
        // Convert game to data
        let data: Data? = encoder()
        
        // Send new game to other players
        if let data = data {
            match.participantQuitInTurn(with: .lost, nextParticipants: players, turnTimeout: GKExchangeTimeoutDefault, match: data, completionHandler: {error in
                if let error = error {
                    print("Saving match data error: \(error)")
                }
            })
        }
        
        // End the match if there are no more players
        endMatchIfNoMorePlayers()
    }
    
    /// Updates the given achievement for the given player if they are the local Game Center player.
    /// - Parameters:
    ///   - playerName: The name of the player that won the achievement.
    ///   - achievementID: The achievement won.
    ///   - byAmount: The amount to update the achievement by.
    public static func updateAchievementForGame(for playerName:String, achievementID:String, byAmount:Double = 100.0) {
        
        // Can the player win achievements?
        guard GKLocalPlayer.local.isAuthenticated && GKLocalPlayer.local.displayName == playerName else {
            return
        }
        
        // Load started and completed achievements for local player
        GKAchievement.loadAchievements(completionHandler: {results, error in
            if let error = error {
                Log.error(subsystem: "Game Center", category: "updateAchievementForGame", "Error loading achievements: \(error)")
                return
            }
            
            var achievements:[GKAchievement] = []
            if let results = results {
                achievements = results
            }
            
            // Update the given achievement
            updateAchievement(id: achievementID, in: achievements, byAmount: byAmount)
            
        })
    }
    
    /// Gets the achievements matching the given ID.
    /// - Parameters:
    ///   - id: The id to find.
    ///   - achievements: The list of available achievements.
    /// - Returns: Returns the requested achievement or a new achievement if not found.
    private static func getAchievement(for id:String, in achievements:[GKAchievement]) -> GKAchievement {
        // Scan all existing achievements
        for achievement in achievements {
            if achievement.identifier == id {
                return achievement
            }
        }
        
        // Else create new achievement and return
        return GKAchievement(identifier: id)
    }
    
    /// Sends the given achievement update to Game Center for the current player.
    /// - Parameters:
    ///   - id: The ID of the Achievement won.
    ///   - achievements: The list of available achievements.
    ///   - byAmount: The amount that the achievement updated by.
    private static func updateAchievement(id:String, in achievements:[GKAchievement], byAmount:Double) {
        let achievement = getAchievement(for: id, in: achievements)
        
        // Has the user already finished this achievement?
        if achievement.isCompleted {
            return
        }
        
        // Update achievement by the given amount
        let amount = achievement.percentComplete + byAmount
        if amount > 100.0 {
            achievement.percentComplete = 100.0
        } else {
            achievement.percentComplete = amount
        }
        
        // Send results to Game Center
        GKAchievement.report([achievement], withCompletionHandler: {error in
            if let error = error {
                Log.error(subsystem: "Game Center", category: "updateAchievement", "Error saving achievement: \(error)")
            }
        })
    }
    
    /// Terminates the current match if all of the players have quit.
    public static func endMatchIfNoMorePlayers() {
        
        // Ensure a match currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            return
        }
        
        // Ensure an encoder was attached.
        guard let encoder = GameCenterManager.shared.gameStateEncoder else {
            return
        }
        
        // Get the number of currectly active players
        var active = 0
        for participant in match.participants {
            switch(participant.status) {
            case .active, .matching, .invited:
                if participant.matchOutcome == .none {
                    active += 1
                }
            default:
                break
            }
        }
        
        // Out of players?
        if active <= 1 {
            // Send status update to other players that the game is over
            if let handler = GameCenterManager.shared.gameEnded {
                handler()
            }
            
            // Convert game to data
            let data: Data? = encoder()
            
            // Send new game to other players
            if let data = data {
                match.endMatchInTurn(withMatch: data, completionHandler: {error in
                    if let error = error {
                        Log.error(subsystem: "Game Center", category: "endMatchIfNoMorePlayers", "Saving match data error: \(error)")
                    }
                })
            }
        }
    }
    
    /// Starts a new game if no game is available.
    /// - Parameters:
    ///   - completed: The completion handler for the new game.
    public static func startNewGame(completed:LoadGameDataCompletionHandler? = nil) {
        
        // Ensure a match is currently open.
        guard let match = GameCenterManager.shared.currentMatch else {
            if let completed {
                completed(false)
            }
            return
        }
        
        // Ensure that a new game can be started.
        guard let newGame = GameCenterManager.shared.startNewGame else {
            if let completed {
                completed(false)
            }
            return
        }
        
        // Ensure an encoder was attached.
        guard let encoder = GameCenterManager.shared.gameStateEncoder else {
            if let completed {
                completed(false)
            }
            return
        }
        
        // Start new game
        newGame()
        
        // Update result of turn
        if let handler = GameCenterManager.shared.gameStarted {
            handler()
        }
        
        // Convert game to data
        let data: Data? = encoder()
        
        // Send new game to other players
        if let data = data {
            match.saveCurrentTurn(withMatch: data, completionHandler: {error in
                if let error = error {
                    Log.error(subsystem: "Game Center", category: "startNewGame", "Saving match data error: \(error)")
                    if let completed = completed {
                        completed(false)
                    }
                } else {
                    if let completed = completed {
                        completed(true)
                    }
                }
            })
        }
    }
    
    /// Loads a match from the given Game Center data stream.
    /// - Parameters:
    ///   - canStartNewGame: If `true`, Game Center can start a new game if one isn't already started.
    ///   - completed: The completion handler for the new game being started.
    public static func loadMatch(canStartNewGame:Bool = false, completed:LoadGameDataCompletionHandler? = nil) {
        
        // Ensure a match is currently open
        guard let match = GameCenterManager.shared.currentMatch else {
            if let completed = completed {
                completed(false)
            }
            return
        }
        
        // Ensure that a game state decoder was attached.
        guard let decoder = GameCenterManager.shared.gameStateDecoder else {
            if let completed = completed {
                completed(false)
            }
            return
        }
        
        match.loadMatchData(completionHandler: {data, error in
            if let error = error {
                Log.error(subsystem: "Game Center", category: "loadMatch", "Loading match data error: \(error)")
                if let completed = completed {
                    completed(false)
                }
                return
            }
            
            if let data {
                if decoder(data) {
                    if let completed = completed {
                        completed(true)
                    }
                } else {
                    if MultiplayerGameManager.isLocalPlayersTurn && canStartNewGame {
                        MultiplayerGameManager.startNewGame(completed: completed)
                    } else {
                        if let completed = completed {
                            completed(false)
                        }
                    }
                }
            } else {
                Log.error(subsystem: "Game Center", category: "loadMatch", "No data returned from match.")
                if let completed = completed {
                    completed(false)
                }
            }
        })
    }
    
    // MARK: - Functions
    /// Handle the player accepting a match invite.
    /// - Parameters:
    ///   - player: The player receiving the invite.
    ///   - invite: The invite to handle.
    public func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player accepted invite.")
    }
    
    /// Handle the player receiving a challenge.
    /// - Parameters:
    ///   - player: The player receiving the challenge.
    ///   - challenge: The challenge received.
    public func player(_ player: GKPlayer, didReceive challenge: GKChallenge) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player received challenge.")
    }
    
    /// Handles the player wanting to lay the game.
    /// - Parameters:
    ///   - player: The player being requested to play.
    ///   - challenge: The play request challenge.
    public func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player wants to play.")
    }
    
    /// Handle the match ending.
    /// - Parameters:
    ///   - player: The player being informated that the match ended.
    ///   - match: The match that has enede.
    public func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player ended match.")
        
        // Save as current match
        GameCenterManager.shared.currentMatch = match
        
        // Load game data and send player to lobby
        MultiplayerGameManager.loadMatch(canStartNewGame: false, completed: {_ in
            // Inform caller that the view needs to change
            if let handler = GameCenterManager.shared.changeView {
                Execute.onMain {
                    handler(match.status)
                }
            }
        })
    }
    
    /// Handle the player wanting to quit the match.
    /// - Parameters:
    ///   - player: The player that wants to quit.
    ///   - match: The match that the player wants to quit.
    public func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player wants to quit match.")
        
        // Save as current match
        GameCenterManager.shared.currentMatch = match
        
        // Load game data and remove given player from the match
        MultiplayerGameManager.loadMatch(canStartNewGame: false, completed: {successful in
            if successful {
                if player.displayName == match.currentParticipant?.player?.displayName {
                    MultiplayerGameManager.quitInTurn(outcome: .quit, displayName: player.displayName)
                } else {
                    MultiplayerGameManager.quitOutOfTurn(displayName: player.displayName)
                }
            }
        })
    }
    
    // !!!: Player Received Turn
    /// Handles the player receiving a Game Center match evemt.
    /// - Parameters:
    ///   - player: The player that received the event.
    ///   - match: The match that the event is for.
    ///   - didBecomeActive: If `true`, the match became active.
    public func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player received turn based event: \(didBecomeActive)")
        
        // Save as current match
        GameCenterManager.shared.currentMatch = match
        
        // Load game data and send player to the correct screen based on state
        MultiplayerGameManager.loadMatch(canStartNewGame: false, completed: {successful in
            if successful {
                // Let the player know a match event has occurred.
                if let handler = GameCenterManager.shared.playerMatchEvent {
                    handler(GKLocalPlayer.local)
                }
                
                // Inform caller that the view needs to change
                if let handler = GameCenterManager.shared.changeView {
                    Execute.onMain {
                        handler(match.status)
                    }
                }
            } else {
                // Game not started, start new game
                MultiplayerGameManager.startNewGame(completed: {saved in
                    // Let the player know a match event has occurred.
                    if let handler = GameCenterManager.shared.playerMatchEvent {
                        handler(GKLocalPlayer.local)
                    }
                    
                    // Inform caller that the view needs to change
                    if let handler = GameCenterManager.shared.changeView {
                        Execute.onMain {
                            handler(match.status)
                        }
                    }
                })
            }
        })
    }
    
    public func player(_ player: GKPlayer, didComplete challenge: GKChallenge, issuedByFriend friendPlayer: GKPlayer) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player did complete challenge.")
    }
    
    public func player(_ player: GKPlayer, issuedChallengeWasCompleted challenge: GKChallenge, byFriend friendPlayer: GKPlayer) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player issued challenge was completed.")
    }
    
    public func player(_ player: GKPlayer, receivedExchangeRequest exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player received exchange request.")
    }
    
    public func player(_ player: GKPlayer, receivedExchangeCancellation exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player received exchange cancellation.")
    }
    
    public func player(_ player: GKPlayer, receivedExchangeReplies replies: [GKTurnBasedExchangeReply], forCompletedExchange exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch) {
        Debug.info(subsystem: "Game Center", category: "MultiplayerGameManager", "Player received exchange replies.")
    }
}
