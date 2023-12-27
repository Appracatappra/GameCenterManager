# Game Center Manager

![](https://img.shields.io/badge/license-MIT-green) ![](https://img.shields.io/badge/maintained%3F-Yes-green) ![](https://img.shields.io/badge/swift-5.4-green) ![](https://img.shields.io/badge/iOS-17.0-red) ![](https://img.shields.io/badge/macOS-14.0-red) ![](https://img.shields.io/badge/tvOS-17.0-red) ![](https://img.shields.io/badge/watchOS-10.0-red) ![](https://img.shields.io/badge/dependency-LogManager-orange) ![](https://img.shields.io/badge/dependency-SwiftletUtilities-orange)

`GameCenterManager` provides a simply way to add Game Center Turn-Based Multiplayer game support to an app.

## Support

If you find `GameCenterManager` useful and would like to help support its continued development and maintenance, please consider making a small donation, especially if you are using it in a commercial product:

<a href="https://www.buymeacoffee.com/KevinAtAppra" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

It's through the support of contributors like yourself, I can continue to build, release and maintain high-quality, well documented Swift Packages like `GameCenterManager` for free.

## Installation

**Swift Package Manager** (Xcode 11 and above)

1. In Xcode, select the **File** > **Add Package Dependency…** menu item.
2. Paste `https://github.com/Appracatappra/GameCenterManager.git` in the dialog box.
3. Follow the Xcode's instruction to complete the installation.

> Why not CocoaPods, or Carthage, or etc?

Supporting multiple dependency managers makes maintaining a library exponentially more complicated and time consuming.

Since, the **Swift Package Manager** is integrated with Xcode 11 (and greater), it's the easiest choice to support going further.

## Overview

By using `GameCenterManager` and `MultiplayerGameManager`, you'll greatly decrease the amount of boilerplate code that is required to support Game Center Turn-Based Multiplayer games in your app.

### Wire-up GameCenterManager Events

Before your game view start, you'll need to wire-up `GameCenterManage' events. You can use the following code on your main app:

```swift
import SwiftUI
import SwiftletUtilities
import LogManager
import SwiftUIKit

@main
struct PackageTesterApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldScenePhase, newScenePhase in
            switch newScenePhase {
            case .active:
                Debug.info(subsystem: "PackageTesterApp", category: "Scene Phase", "App is active")
            case .inactive:
                Debug.info(subsystem: "PackageTesterApp", category: "Scene Phase", "App is inactive")
            case .background:
                Debug.info(subsystem: "PackageTesterApp", category: "Scene Phase", "App is in background")
            @unknown default:
                Debug.notice(subsystem: "PackageTesterApp", category: "Scene Phase", "App has entered an unexpected scene: \(oldScenePhase), \(newScenePhase)")
            }
        }
    }
}

/// Class the handle the event that would typically be handled by the Application Delegate so they can be handled in SwiftUI.
class AppDelegate: NSObject, UIApplicationDelegate {
    
    /// Handles the app finishing launching
    /// - Parameter application: The app that has started.
    func applicationDidFinishLaunching(_ application: UIApplication) {
        // Register to receive remote notifications
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    /// Handle the application getting ready to launch
    /// - Parameters:
    ///   - application: The application that is going to launch.
    ///   - launchOptions: Any options being passed to the application at launch time.
    /// - Returns: Returns `True` if the application can launch.
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    
        // Wireup Game Center Events
        GameCenterManager.shared.gameStateEncoder = {
            // TODO: Insert your code here to encode your game state.
            return MasterDataStore.shared.gameState.encoded
        }
        
        GameCenterManager.shared.gameStateDecoder = { data in
            // TODO: Insert your code here to decode your game state. Return `true` if successfully decoded.
            if let state = MurderCase(from: data) {
                MasterDataStore.shared.gameState = state
                return true
            } else {
                return false
            }
        }
        
        GameCenterManager.shared.playerTurnEnd = { player, participants in
            // TODO: Handle the player's turn ending.
            MasterDataStore.shared.gameState.playerTurnEnded(player: player, participants: participants)
        }
        
        GameCenterManager.shared.playerQuitInTurn = { player, participants in
            // TODO: Handle the player quitting in-turn.
            MasterDataStore.shared.gameState.playerQuit()
        }
        
        GameCenterManager.shared.playerQuitOutOfTurn = { player in
            // TODO: Handle the player quitting out-of-turn.
            MasterDataStore.shared.gameState.playerQuit()
        }
        
        GameCenterManager.shared.playerWonGame = { player in
            // TODO: Handle a player winning the game.
            MasterDataStore.shared.gameState.playerWon(player: player)
        }
        
        GameCenterManager.shared.playerLostGame = { playerName in
            // TODO: Handle the player losing the game.
            MasterDataStore.shared.gameState.playerLost(playerName: playerName)
        }
        
        GameCenterManager.shared.startNewGame = {
            // TODO: Handle a new game starting.
            if let match = GameCenterManager.shared.currentMatch {
                MasterDataStore.shared.gameState = MurderCase.BuildMurder(numberOfPlayers: match.participants.count, isMultiplayer: true)
            }
        }
        
        GameCenterManager.shared.changeView = { matchState in
            // TODO: Handle a request to switch view based on the match state.
            switch matchState {
            case .ended:
                MasterDataStore.shared.gameState.endOfGameStats()
                MasterDataStore.shared.changeView(newView: .gameLobby)
            case .open, .matching:
                MasterDataStore.shared.gameState.showGameboard()
            default:
                MasterDataStore.shared.changeView(newView: .gameLobby)
            }
        }
        
        GameCenterManager.shared.playerMatchEvent = { player in
            // TODO: Handle the player receiving a match event (such as another player making a move).
            MasterDataStore.shared.gameState.assignPlayerToDetective(teamPlayerId: player.displayName)
            MasterDataStore.shared.gameState.setCurrentPlayer()
            MultiplayerConversations.startTurn()
        }
        
        // Informthe app that the launch has completed successfully.
        return true
    }
    
    /// Handles the app receiving a remote notification
    /// - Parameters:
    ///   - application: The app receiving the notifications.
    ///   - userInfo: The info that has been sent to the App.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        
    }
}
```

With this code in place, make any style changes in `func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool` and they apply to all views built afterwards.


## ConnectToGameCenter Helper View

The following `ConnectToGameCenter` helper View makes it easier to connect to game center, taking over much of the boilerplate that is required:

```swift
import SwiftUI
import SwiftletUtilities
import GameKitUI
import GameKit
import GameCenterManager
import StoreKit
import LogManager
import AppStoreManager
import SoundManager
import SwiftUIKit

struct ConnectToGameCenter: View {
    typealias AccessPointvent = () -> Bool
    
    var location:GKAccessPoint.Location = .topTrailing
    var shouldDisplayAccessPoint:AccessPointvent? = nil
    
    @State private var checkForGameCenter:Bool = true
    
    var body: some View {
        if checkForGameCenter {
            GKAuthenticationView(failed: {error in
                Debug.info(subsystem: "Game Center", category: "Login", "Failed: \(error.localizedDescription)")
                Execute.onMain {
                    GameCenterManager.shared.isGameCenterEnabled = false
                    checkForGameCenter = false
                }
            }, authenticated: {player in
                Debug.info(subsystem: "Game Center", category: "Login", "Hello \(player.displayName)")
                GKAccessPoint.shared.location = location
                
                // Should we display the access point?
                if let test = shouldDisplayAccessPoint {
                    if test() {
                        GKAccessPoint.shared.isActive = GKLocalPlayer.local.isAuthenticated
                    } else {
                        GKAccessPoint.shared.isActive = false
                    }
                } else {
                    GKAccessPoint.shared.isActive = GKLocalPlayer.local.isAuthenticated
                }
                
                // Has a listener been registered
                if GameCenterManager.shared.currentGameManager == nil && GKLocalPlayer.local.isAuthenticated {
                    GameCenterManager.shared.currentGameManager = MultiplayerGameManager()
                        GKLocalPlayer.local.register(GameCenterManager.shared.currentGameManager!)
                    Debug.info(subsystem: "Game Center", category: "Multiplayer Game", "Game Manager registered")
                    }
                
                Execute.onMain {
                    GameCenterManager.shared.allowMultiplayer = (GKLocalPlayer.local.isAuthenticated && !GKLocalPlayer.local.isMultiplayerGamingRestricted)
                    GameCenterManager.shared.isGameCenterEnabled = true
                    checkForGameCenter = false
                }
            })
        }
    }
}

#Preview {
    ConnectToGameCenter()
}
``` 

Use this code in your app's first view to connect the player to Game Center:

```swift
import SwiftUI
import SwiftletUtilities
import GameKitUI
import GameKit
import GameCenterManager
import StoreKit
import LogManager
import AppStoreManager
import SoundManager
import SwiftUIKit
import SpeechManager

struct MainMenuLandscape: View {
    @ObservedObject var dataStore = MasterDataStore.shared
    
    var body: some View {
        ZStack {
            ...
            
            ConnectToGameCenter() {
                // TODO: Switch to the correct view when connected. 
                return (dataStore.currentView == .menuView)
            }
        } // End of ZStack
        .onDisappear() {
            GKAccessPoint.shared.isActive = false
        }
    }
}

#Preview {
    MainMenuLandscape()
}
```

### Using MultiplayerGameManger

The `MultiplayerGameManger` class allows you to send game state changes to Game Center for your turn-based app. These are the most often used features via a static call to `MultiplayerGameManger`:

* `isLocalPlayersTurn` - If `true` it is the local player's turn.
* `sendStatusUpdate()` - Sends any game state changes to all players, such as the current player making a move.
* `endTurn()` - Ends the current player's turn.
* `quitInTurn(outcome:GKTurnBasedMatch.Outcome, displayName:String = GKLocalPlayer.local.displayName)` - Handles the current player quitting during their turn.
* `quitOutOfTurn(displayName:String = GKLocalPlayer.local.displayName)` - Handles a player quitting outside of their turn.
* `getGameCenterPlayer(for displayName:String)` - Returns the player with the given display name.
* `savePlayerScore(of score:Int, for player:GKPlayer, leaderBoards:[String])` - Saves a player's score to the given list of Game Center Leaderboards.
* `wonGame(displayName:String)` - Inform Game Center the player won the game.
* `lostGame()` - Inform game center the current player lost the game.
* `updateAchievementForGame(for playerName:String, achievementID:String, byAmount:Double = 100.0)` - Updates an achievement for the given player by the given amount.

# Documentation

The **GraceLanguage Package** includes full **DocC Documentation** for all of its features.

