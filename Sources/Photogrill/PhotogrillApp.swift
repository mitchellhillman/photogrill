import SwiftUI

@main
struct PhotogrillApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 700)
    }

    // Dock + app icon — references AppIcon in Assets.xcassets
    // (Xcode picks this up automatically via the asset catalog)
}
