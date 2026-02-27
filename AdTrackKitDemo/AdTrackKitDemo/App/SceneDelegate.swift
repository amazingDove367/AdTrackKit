//
//  SceneDelegate.swift
//  AdTrackKitDemo
//
//  Created by kingj on 2/16/26.
//

import UIKit
import AdTrackKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        let nav = UINavigationController(rootViewController: ShopViewController())
        nav.navigationBar.prefersLargeTitles = false
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        print("📱 앱이 포그라운드로 복귀")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        ATKTracker.shared.flush()
        print("📱 앱이 백그라운드로 전환됨 -> flush() 호출")
    }
}

