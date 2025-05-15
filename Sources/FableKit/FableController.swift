import SwiftUI
import RealityKit
import AsyncAlgorithms
import Logging
import LoggingSlack
import LoggingOSLog

@Observable
@MainActor
public class FableController {
    nonisolated private static let userDefaultsLogHandler = UserDefaultsLogHandler()
    nonisolated private static let logger = {
        let webhook = URL(string: "https://hooks.slack.com/services/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")!
        
        LoggingSystem.bootstrap { label in
            var slackLog = SlackLogHandler(label: label, webhookURL: webhook)
            
            return MultiplexLogHandler([
                slackLog,
                StreamLogHandler.standardError(label: label),
                LoggingOSLog.init(label: label),
                userDefaultsLogHandler
            ])
        }
        return Logger(label: "com.visionstorage.classroom")
    }()
    
    @MainActor internal var renderer: FableRenderer
    @MainActor public private(set) var fable: Fable
    public var currentElement: Element?
    
    public let controlChannel = AsyncChannel<ControlMessage>()
    public static var defaultBundle: Bundle = .main
    
    public var isFrozen = false
    
    public var loopAround = true
    
    nonisolated private let fableID: UUID
    
    public var immersionStyle: any ImmersionStyle = .mixed
    
    public var isReady: Bool {
        self.fable.isReady
    }
    
    public var startTime: Date?
    public var endTime: Date?
    
    public var onFinished: (() -> ())?
    
    @MainActor
    public init(fable: Fable, loopAround: Bool = true, onFinished: (() -> ())? = nil) {
        self.renderer = FableRenderer()
        self.fable = fable
        self.loopAround = loopAround
        self.fableID = fable.id
        self.onFinished = onFinished
        
        renderer.controllerContext = self
        fable.elements.forEach { $0._controllerContext = self }
        
        Task.detached {
            for await message in self.controlChannel {
                switch message {
                    case .next:
                        await self.next()
                    case .reset:
                        await self.reset()
                }
            }
        }
        
        Self.register(self)
    }
    
    deinit {
        Self.unregister(self)
    }
    
    public var body: some View {
        renderer.body
            .onAppear {
                if self.isFrozen { Task { @MainActor in await self.reset() } }
                else { self.next() }
            }
    }
    
    public func next() {
        guard fable.isReady else { return }
        
        if let currentElement {
            renderer.remove(element: currentElement)
        } else {
            startTime = Date()
        }
        
        guard let nextElement = fable.next() else {
            currentElement = nil
            onFinished?()
            if loopAround {
                self.fable.isReady = false
                Task {
                    await self.reset()
                }
            }
            return
        }
        
        renderer.add(element: nextElement)
        currentElement = nextElement
    }
    
    public func freeze() {
        logPlaytime()
        isFrozen = true
        Task {
            await renderer.sendGlobalMessage(.freeze)
        }
    }
    
    public func unfreeze() {
        Task {
            await renderer.sendGlobalMessage(.unfreeze)
        }
        isFrozen = false
    }
    
    public func reset() async {
        logPlaytime()
        
        await self.renderer.reset()
        await self.fable.reset()
        self.currentElement = nil
        fable.elements.forEach { $0._controllerContext = self }
        self.startTime = nil
        self.endTime = nil
        self.unfreeze()
    }
    
    public func logPlaytime() {
        guard let startTime else { return }
        endTime = Date()
        let duration = startTime.distance(to: endTime!)
        
        Self.logger.log(level: .critical, "Player ended session: Runtime \(duration) secs. (\(startTime.formatted(date: .omitted, time: .shortened)) ~ \(endTime!.formatted(date: .omitted, time: .shortened)))")
        
        self.startTime = nil
        endTime = nil
    }
    
    public func findElement(id: UUID) -> Element? {
        if let element = self.fable.elements.first(where: { $0.id == id }) { return element }
        else {
            for element in self.fable.elements {
                if let foundElement = element.getChild(id: id) {
                    return foundElement
                }
            }
            return nil
        }
    }
}

public enum ControlMessage: Sendable {
    case next
    case reset
}

public extension FableController {
    static internal private(set) var activeControllers: [UUID : FableController] = [:]
    
    static subscript(for uuid: UUID) -> FableController? {
        return activeControllers[uuid]
    }
    
    static func register(_ controller: FableController) {
        activeControllers[controller.fableID] = controller
    }
    
    nonisolated static func unregister(_ controller: FableController) {
        Task { @MainActor in
            activeControllers.removeValue(forKey: controller.fableID)
        }
    }
}
