import SwiftUI

public struct FableView: View {
    @Environment(FableController.self) var controller
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.openWindow) var openWindow
    
    public var body: some View {
        controller.body
            .onChange(of: scenePhase) { oldValue, newValue in
                if newValue == .background {
                    self.controller.freeze()
                } else {
                    Task { await self.controller.reset() }
                }
            }
    }
    
    public init() {}
}

public struct FableScene: Scene {
    public var body: some Scene {
        ImmersiveSpace {
            FableView()
        }
    }
}
