import SwiftUI
import RealityKit
import AVKit
import AsyncAlgorithms

public typealias RenderEventHandler = @MainActor @Sendable (Element, FableRenderer) -> ()
public typealias RealityViewUpdateEventHandler = @MainActor @Sendable (inout RealityViewContent, borrowing RealityViewAttachments, FableRenderer) -> ()
public typealias AsyncEventHandler = @MainActor @Sendable (Element) async -> ()
public typealias RendererTask = @MainActor @Sendable (FableRenderer) async -> ()
public typealias LifecycleMessageHandler = @Sendable (LifecycleMessage, FableRenderer) -> ()

public class Element: Identifiable, @unchecked Sendable {
    internal(set) public var id: UUID
    
    public internal(set) var realityKitEntity: Entity?
    public internal(set) var realityKitAttachment: AnyView?
    //internal var realityKitAttachment: AttachmentView?
    
    public var isEventElement: Bool {
        self.realityKitEntity == nil
    }
    
    public var isNonRenderingElement: Bool = false
    
    public internal(set) weak var parent: Element? = nil
    public internal(set) var children: Set<Element> = []
    
    internal unowned var _controllerContext: FableController?
    public unowned var controllerContext: FableController {
        guard let _controllerContext else {
            guard let parent = self.parent else { fatalError() }
            return parent.controllerContext
        }
        
        return _controllerContext
    }
    
    internal unowned var rendererContext: FableRenderer?
    
    @MainActor
    internal unowned var defaultBundle: Bundle {
        FableController.defaultBundle
    }
    
    internal unowned var controlChannel: AsyncChannel<ControlMessage> {
        self.controllerContext.controlChannel
    }
    
    public internal(set) var onLoad: [AsyncEventHandler] = []
    public internal(set) var onDidLoad: [AsyncEventHandler] = []
    public internal(set) var willRender: [RenderEventHandler] = []
    public internal(set) var didRender: [RenderEventHandler] = []
    public internal(set) var willDestroy: [AsyncEventHandler] = []
    public internal(set) var didDestroy: [AsyncEventHandler] = []
    
    public var isRendered: Bool = false
    public var isDestroyed: Bool = false
    public var isBeingDestroyed: Bool = false
    
    public var isRoot: Bool = false
    
    internal var messageChannel = AsyncChannel<LifecycleMessage>()
    internal var messageHandler: [LifecycleMessage: LifecycleMessageHandler] = [:]
    
    /// a function that returns if lifetime of the element has ended of not. `true` means the object is still alive.
    public var lifetimeSignal: () -> (Bool) = { true }
    
    public var metadata: [MetadataKey : Any] = [:]
    
    public var transform: Transform = .identity
    public var coordinateSpaceAnchor: CoordinateSpaceAnchor = .parent
    
    public var eventList: [(time: Duration, handler: AsyncEventHandler)] = []
    
    public var childRenderTasks: [Task<Void, any Error>] = []
    
    public let selfTimeKeeping: Bool
    
    #if DEBUG
    internal var debugMode: Bool = false
    #endif
    
    @MainActor public init(id: UUID = UUID(), entity: Entity? = nil, @ElementBuilder children: () -> [Element] = {[]}, selfTimeKeeping: Bool = false) {
        self.id = id
        self.realityKitEntity = entity ?? Entity()
        
        self.children = Set(children())
        
        self.selfTimeKeeping = selfTimeKeeping
        
        for child in self.children {
            child.parent = self
        }
    }
    
    internal init(isEventElement: Bool) {
        self.id = UUID()
        self.selfTimeKeeping = false
    }
    
    func message(_ message: LifecycleMessage, propagate: Bool = true) async {
        await self.messageChannel.send(message)
        
        if propagate {
            await withTaskGroup(of: Void.self) { group in
                for child in children {
                    group.addTask {
                        await child.message(message, propagate: true)
                    }
                }
            }
        }
    }
    
    func setAliveStatus(_ lifetimeSignal: @escaping @autoclosure () -> Bool) {
        self.lifetimeSignal = lifetimeSignal
    }
    
    @MainActor
    public func transformReset() {
        guard let realityKitEntity else { return }
        if coordinateSpaceAnchor == .parent {
            realityKitEntity.setTransformMatrix(transform.matrix, relativeTo: parent?.realityKitEntity)
        } else {
            realityKitEntity.setTransformMatrix(transform.matrix, relativeTo: nil)
        }
    }
    
    @MainActor func load() async {
        notify("loading \(self.description)")
        
        if self.isEventElement {
            guard self.children.isEmpty else { fatalError("Event elements cannot have children.") }
            guard self.realityKitAttachment == nil else { fatalError("Event elements cannot have a view attachment.")}
        }
        
        transformReset()
        
        for loadEvent in onLoad {
            await loadEvent(self)
        }
        
        notify("loaded \(self.description)")
        notify("loading children of \(self.description)")
        
        transformReset()
        
        for child in children {
            child.parent = self
            await child.load()
        }
        
        notify("loaded children of \(self.description)")
        
        for loadEvent in onDidLoad {
            await loadEvent(self)
        }
    }
    
    @MainActor func render(content: inout RealityViewContent, attachments: borrowing RealityViewAttachments, renderer: FableRenderer) {
        self.rendererContext = renderer
        
        willRender.forEach {
            $0(self, renderer)
        }
        
        notify("willRender finished \(self.description)")
        
        if let realityKitEntity {
            content.add(realityKitEntity)
        }
        isRendered = true
        
        notify("added to renderer \(self.description)")
        
        Attachment:
        if realityKitAttachment != nil {
            guard let realityKitEntity else { fatalError("Views cannot be attached to Event Elements.")}
            // Wait one tick and then query attachments, since attachment might not be present in the scene yet.
            Task { @MainActor in
                for await _ in renderer.tickChannel {
                    await renderer.updateTaskQueue.send { content, attachments, renderer in
                        guard let attachmentEntity = attachments.entity(for: self.id) else {
                            return
                        }
                        attachmentEntity.components.set(OpacityComponent())
                        realityKitEntity.addChild(attachmentEntity)
                        attachmentEntity.transform = .identity
                    }
                    
                    break
                }
            }
            
            notify("requested attachments \(self.description)")
        }
        
        notify("checked attachments \(self.description)")

        Task {
            await renderer.taskQueue.send { [didRender] renderer in
                didRender.forEach {
                    $0(self, renderer)
                }
            }
            
            notify("didRender finished \(self.description)")
        }
        
        notify("requested didrender \(self.description)")
        
        Task.detached {
            for await message in self.messageChannel {
                self.messageHandler[message]?(message, renderer)
            }
        }
        
        notify("listening to the message chaannel \(self.description)")
        
        if !selfTimeKeeping {
            for child in children {
                if let appearTime = child.metadata[.appearAt] as? Duration {
                    let appearTask = Task.detached {
                        try? await Task.sleep(for: appearTime)
                        try Task.checkCancellation()
                        renderer.add(element: child)
                    }
                    childRenderTasks.append(appearTask)
                } else {
                    renderer.add(element: child)
                }
                
                if let disappearTime = child.metadata[.disappearAt] as? Duration {
                    let disappearTask = Task.detached {
                        try? await Task.sleep(for: disappearTime)
                        try Task.checkCancellation()
                        renderer.remove(element: child)
                    }
                    childRenderTasks.append(disappearTask)
                }
            }
            for event in eventList {
                let eventTask = Task.detached {
                    try? await Task.sleep(for: event.time)
                    try Task.checkCancellation()
                    await event.handler(self)
                }
                childRenderTasks.append(eventTask)
            }
            
            notify("registered events \(self.description)")
        }
    }
    
    func notify(_ message: CustomStringConvertible) {
        #if DEBUG
        if debugMode { print(message.description) }
        #endif
    }
    
    @MainActor func remove(renderer: FableRenderer) async {
        guard self.isBeingDestroyed == false else { return }
        self.isBeingDestroyed = true
        notify("removing \(self.description)")
        
        childRenderTasks.forEach { $0.cancel() }
        
        notify("cancelling child render queue \(self.description)")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for destroyEvent in self.willDestroy {
                    await destroyEvent(self)
                }
            }
            
            for child in self.children {
                group.addTask {
                    await child.remove(renderer: renderer)
                }
            }
        }
        
        notify("willDestroy finished \(self.description)")
        
        for didDestroyEvent in self.didDestroy {
            Task.detached { await didDestroyEvent(self) }
        }
        
        notify("launched didDestroy \(self.description)")
        
        self.realityKitEntity?.removeFromParent()
        self.parent?.children.remove(self)
        
        self.isBeingDestroyed = false
        self.isDestroyed = true
        
        notify("removed \(self.description)")
    }
    
    func getChild(id: UUID) -> Element? {
        if let child = self.children.first(where: { $0.id == id }) { return child }
        else {
            for child in self.children {
                if let foundChild = child.getChild(id: id) { return foundChild }
            }
            return nil
        }
    }
    
    deinit {
        messageChannel.finish()
    }
    
    public enum CoordinateSpaceAnchor: Equatable {
        case parent
        case world
    }
}

extension Element: Hashable {
    nonisolated public static func == (lhs: Element, rhs: Element) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
        hasher.combine(self.transform)
        hasher.combine(self.isRendered)
        hasher.combine(self.isDestroyed)
        hasher.combine(self.realityKitEntity?.id)
    }
}

extension Element: CustomStringConvertible {
    public var description: String {
        (self.metadata[.description] as? String) ?? self.id.uuidString
    }
}

public enum LifecycleMessage: Sendable, Hashable {
    // Renderer -> Element
    case willDestroy(in: Duration)
    case freeze
    case unfreeze
    
    // Element -> Renderer
//    case selfDestroy(of: Element)
}
