//
//  AppDelegate.swift
//  AdTrackKitDemo
//
//  Created by kingj on 2/16/26.
//

import UIKit
import AdTrackKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // ────────────────────────
        // SDK 초기화 (Builder 패턴)
        // ────────────────────────
        let config = ATKConfiguration.builder(appKey: "demo-app-key-123")
            .setEnvironment(.development) // 개발 환경
            .setLogLevel(.debug)          // 모든 로그 출력
            .setBatchSize(5)              // 5개 모이면 전송
            .setBatchInterval(10.0)       // 10초마다 체크
            .build()

        ATKTracker.shared.initialize(with: config)

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // 앱이 완전히 종료될 때 (iOS가 메모리에서 제거)
    func applicationWillTerminate(_ application: UIApplication) {
        ATKTracker.shared.flush()
        print("📱 앱이 종료됨 -> flush() 호출")
    }

}

