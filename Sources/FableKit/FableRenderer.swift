import SwiftUI
import RealityKit
import AsyncAlgorithms
import ARKit
import simd
import AVFoundation

//@MainActor
@Observable
public final class FableRenderer: @unchecked Sendable {
    
    // MARK: Elements
    
    @ObservationIgnored public private(set) var elements: [Element] = [] {
        didSet {
            elementsWithAttachment = self.elements.filter { $0.realityKitAttachment != nil }
            Task { @MainActor in updateView() }
        }
    }
    
    @ObservationIgnored var elementsWithAttachment: [Element] = []
    
    @ObservationIgnored @MainActor private var elementsToAdd: [Element] = []
    @ObservationIgnored @MainActor private var elementsToRemove: [Element] = []
    
    private var updateCount: Int = 0
    
    private var finishedElements: [Element] {
        elements.filter { $0.lifetimeSignal() == false }
    }
    
    private var destroyedElements: [Element] {
        elements.filter { $0.isDestroyed }
    }
    
    public private(set) var isResetting: Bool = false
    
    // MARK: Accurate Head Tracking
    
    @ObservationIgnored private let arKitSession = ARKitSession()
    @ObservationIgnored private let arKitWorldTrackingProvider = WorldTrackingProvider()
    @ObservationIgnored internal var currentHeadPosition = SIMD3<Float>.zero
    @ObservationIgnored internal var currentHeadRotation = simd_quatf()
    
    @ObservationIgnored private var sceneUpdateSubscription: EventSubscription? = nil
    
    // MARK: Task Queue
    
    @ObservationIgnored var taskQueue = AsyncChannel<RendererTask>()
    @ObservationIgnored var _updateTaskQueue: [RealityViewUpdateEventHandler] = []
    @ObservationIgnored var updateTaskQueue = AsyncChannel<RealityViewUpdateEventHandler>()
    @ObservationIgnored var tickChannel: AsyncChannel<Int> = .init()
    
    // MARK: Surroundings
    
    @MainActor var surroundingsEffect: SurroundingsEffect? = nil
    
    // MARK: Mid-air Interactions
    
//    @MainActor var skybox: Entity = createEmptySkybox()
    
    // MARK: SwiftUI Attachments
    
    var attachments: some AttachmentContent {
        ForEach(self.elementsWithAttachment) { element in
            Attachment(id: element.id) {
                element.realityKitAttachment
            }
        }
    }
    
    // MARK: Context
    
    unowned var controllerContext: FableController!
    
    public init() {}
    
    public func add(element: Element) {
        Task { @MainActor in
            element.notify("adding \(element) to insertion queue")
            self.elementsToAdd.append(element)
            element.notify("added \(element) to insertion queue")
            updateView()
        }
    }
    
    public func remove(element: Element) {
        Task { @MainActor in
            element.notify("adding \(element) to removal queue")
            self.elementsToRemove.append(element)
            element.notify("added \(element) to removal queue")
            updateView()
        }
    }
    
    @MainActor
    public func reset() async {
        self.isResetting = true
        self.elementsToRemove.append(contentsOf: elements)
        self.surroundingsEffect = nil
        updateView()
        
        while self.isResetting {
            await Task.yield()
            updateView()
        }
    }
    
    @MainActor
    public func updateView() {
        updateCount += 1
//        withMutation(keyPath: \.updateCount) {}
    }
    
    public func sendGlobalMessage(_ message: LifecycleMessage) async {
        for element in elements {
            await element.message(message, propagate: true)
        }
    }
    
    @MainActor
    public var body: some View {
        RealityView { content, attachments in
//            content.add(self.skybox)
            
            self.sceneUpdateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                guard let anchor = self.arKitWorldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return }
                
                let toDeviceTransform:simd_float4x4 = anchor.originFromAnchorTransform
                self.currentHeadPosition = toDeviceTransform.translation
                self.currentHeadRotation = simd_quatf(toDeviceTransform.upper3x3)
            }
        } update: { content, attachments in
            self.access(keyPath: \.updateCount)
            Task { await self.tickChannel.send(self.updateCount) }
            
            for element in self.elementsToAdd.filter({ !$0.isRendered }) {
                Task.detached { element.notify("from renderer - adding \(element.description)") }
                element.render(content: &content, attachments: attachments, renderer: self)
                
                self.elementsToAdd.removeAll(where: { $0 == element })
                self.elements.append(element)
            }
            
            self.elementsToRemove.append(contentsOf: self.finishedElements)
            
            for element in self.elementsToRemove {
                Task {
                    Task.detached { element.notify("from renderer - removing \(element.description)") }
                    await element.remove(renderer: self)
                    self.elements.removeAll { $0 == element }
                    self.elementsToRemove.removeAll { $0 == element }
                }
            }
            
            for element in self.destroyedElements {
                self.elements.removeAll { $0 == element }
                self.elementsToRemove.removeAll { $0 == element }
            }
            
            for update in self._updateTaskQueue {
                update(&content, attachments, self)
            }
            
            if self.isResetting, self.elements.isEmpty, self.elementsToRemove.isEmpty {
                self.isResetting = false
            } else if self.isResetting {
                self.elements = []
                self.elementsToRemove = []
                self.elementsToAdd = []
                
                content.entities.removeAll()
            }
        } attachments: {
            self.access(keyPath: \.updateCount)
            return self.attachments
        }
        .installGestures()
        .onAppear {
            Task.detached {
                for await task in self.taskQueue {
                    await task(self)
                    await Task.yield()
                }
            }
            
            Task.detached {
                for await update in self.updateTaskQueue {
                    self._updateTaskQueue.append(update)
                    await self.updateView()
                }
            }
        }
        .task {
            try? await self.arKitSession.run([self.arKitWorldTrackingProvider])
        }
        .preferredSurroundingsEffect(surroundingsEffect)
//        .gesture(SpatialTapGesture().targetedToEntity(skybox).onEnded({ gesture in
//            self.controllerContext.next()
//        }))
    }
}
