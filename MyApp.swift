import SwiftUI

@main
struct MemoryAtlasApp: App {
    @StateObject private var store = MemoryStore()
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MapScreen()
                    .environmentObject(store)
                
                if showSplash {
                    SplashScreen()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
