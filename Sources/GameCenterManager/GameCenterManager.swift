// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import GameKit
import SwiftUI
import SwiftletUtilities
import LogManager

/// A manager that removes most of the boilerplate required to add turn based Game Center gameplay to an app.
@Observable open class GameCenterManager {
    public typealias GameStateEncoder = ()-> Data?
    public typealias GameStateDecoder = (Data) -> Bool
    public typealias PlayerEvent = (GKLocalPlayer) -> Void
    public typealias PlayerNameEvent = (String) -> Void
    public typealias GameCenterManagerEvent = () -> Void
    public typealias MatchEvent = (GKTurnBasedMatch.Status) -> Void
    
    // MARK: - Static Properties
    /// A common shared instance of the library.
    public static var shared:GameCenterManager = GameCenterManager()
    
    // MARK: - Properties
    /// If `true`, Game Ceneter has been enabled for the app.
    public var isGameCenterEnabled:Bool = false
    
    /// If `true`, multiplayer is enabled for the app.
    public var allowMultiplayer:Bool = false
    
    /// Holds the instance of a current turn based game.
    public var currentMatch:GKTurnBasedMatch? = nil
    
    /// Holds the instance of a turn based game match.
    public var currentGameManager:MultiplayerGameManager? = nil
    
    /// Holds an instance of an encode used to encode the game state before sending it to Game Center.
    public var gameStateEncoder:GameStateEncoder? = nil
    
    /// Holds an instance of an encoder used to restore a game state that was sent from Game Center.
    public var gameStateDecoder:GameStateDecoder? = nil
    
    /// Handles the current player's turn ending.
    public var playerTurnEnd:PlayerEvent? = nil
    
    /// Handles the player quitting during their turn.
    public var playerQuitInTurn:PlayerEvent? = nil
    
    /// Handles the player quitting out of their turn.
    public var playerQuitOutOfTurn:PlayerEvent? = nil
    
    /// Handles the player winning the game.
    public var playerWonGame:PlayerEvent? = nil
    
    /// Handles the named player losing the game.
    public var playerLostGame:PlayerNameEvent? = nil
    
    /// Handles the game ending.
    public var gameEnded:GameCenterManagerEvent? = nil
    
    /// Handles Game Center requesting that a new game be started.
    public var startNewGame:GameCenterManagerEvent? = nil
    
    // Handles the game starting.
    public var gameStarted:GameCenterManagerEvent? = nil
    
    /// Handles Game Center requesting that the game's view changes in response to a match event.
    public var changeView:MatchEvent? = nil
    
    /// Handles the player getting a match event.
    public var playerMatchEvent:PlayerEvent? = nil
}
