import SwiftUI

@main
struct SozoroApp: App {
    @StateObject private var location = LocationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(location)
                .preferredColorScheme(.light)
                .task { location.start() }
        }
    }
}
