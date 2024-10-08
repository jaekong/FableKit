import Foundation
import SwiftUI
import RealityKit
import AVKit
import Combine

extension Array where Element: FableKit.Element {
    var expiredElements: Self {
        self.filter { $0.lifetime.isOver }
    }
}

extension Element {
    var lifetimeDecreased: Self {
        var copy = self
        copy.lifetime = copy.lifetime.decreased()
        return copy
    }
    
    var lifetimeExpired: Self {
        var copy = self
        copy.lifetime = copy.lifetime.expired()
        return copy
    }
}

@MainActor
public struct ConcurrentElement: GroupElement {
    nonisolated public var description: String { elements.map { $0.description }.joined(separator: "\n") }
    public var id = UUID()
    public var contentData: ContentData = .concurrent
    var anchorOffset: SIMD3<Float> = .zero
    
    private var _lifetime: Lifetime? = nil
    
    nonisolated public var lifetime: Lifetime {
        get {
            if let _lifetime { return _lifetime }
            
            let isEverythingOver = self.elements.allSatisfy { $0.lifetime.isOver }
            return .indefinite(isOver: isEverythingOver)
        }
        set {
            _lifetime = newValue
        }
    }
    
    public var elements: [any Element]
    public var onRender: RenderEventHandler? = nil
    public var onDisappear: RenderEventHandler? = nil

    // public var parentID: UUID?
    
    private init(from previous: ConcurrentElement, with newElements: [any Element]) {
        self.id = previous.id
        self.contentData = previous.contentData
        self.elements = newElements.map {
            if let parentReferencing = $0 as? (any ParentReferencingElement) {
                return parentReferencing.withParent(previous.id)
            } else {
                return $0
            }
        }
        self.onRender = previous.onRender
        self.onDisappear = previous.onDisappear
        self._lifetime = previous._lifetime
        self.anchorOffset = previous.anchorOffset
    }
    
    func withNewElements(_ newElements: [any Element]) -> Self {
        return Self(from: self, with: newElements)
    }

    // public func withParent(_ parentID: UUID) -> Self {
    //     var copy = self
    //     copy.parentID = parentID
    //     return copy
    // }
}

@MainActor @available(*, deprecated, message: "use Video instead")
public struct TimelinedElement: GroupElement {
    nonisolated public var description: String {
        zip(elements, times).map {
            "\($0.1.seconds.formatted(.number.precision(.fractionLength(2))))s: \($0.0.description)"
        }.joined(separator: "\n")
    }
    public var id = UUID()
    public var contentData: ContentData = .timelined
    public var onRender: RenderEventHandler? = nil
    public var onDisappear: RenderEventHandler? = nil
    
    public var elements: [any Element]
    public let times: [Duration]
    public var lifetime: Lifetime = .indefinite(isOver: false)

    var anchorOffset: SIMD3<Float>
    
    public init(elements: [any Element], times: [Duration], anchorOffset: SIMD3<Float> = .zero) {
        self.elements = elements
        self.times = times
        self.anchorOffset = anchorOffset
        
        let id = self.id
        
        self.onRender = { @Sendable context in
            let events = zip(elements, times)
            for event in events {
                context.addElementToQueue(event.0, after: event.1, taskID: id)
            }
        }
        
        self.onDisappear = { @Sendable context in
            context.cancelQueue(for: id)
        }
    }
    
    private init(from previous: TimelinedElement, with newElements: [any Element]) {
        self.contentData = previous.contentData
        self.onRender = previous.onRender
        self.onDisappear = previous.onDisappear
        self.elements = newElements
        self.lifetime = previous.lifetime
        self.anchorOffset = previous.anchorOffset
        
        let times = previous.times
        let id = previous.id
        
        self.id = id
        self.times = times
        
        self.onRender = { @Sendable context in
            let events = zip(newElements, times)
            for event in events {
                context.addElementToQueue(event.0, after: event.1, taskID: id)
            }
        }
        
        self.onDisappear = { @Sendable context in
            context.cancelQueue(for: id)
        }
    }
    
    func withNewElements(_ newElements: [any Element]) -> Self {
        return Self(from: self, with: newElements)
    }
}

public struct ViewElement: Element, @unchecked Sendable, ParentReferencingElement {
    public var description = "<View>"
    public var id = UUID()
    public var contentData: ContentData
    
    public var body: AnyView
    
    public var onRender: RenderEventHandler? = nil
    public var onDisappear: RenderEventHandler? = nil
    
    public var lifetime: Lifetime = .element(count: 1)
    
    public let isOverlay: Bool
    
    public let initialPosition: Position
    public let initialRotation: Rotation
    
    public var parentID: UUID?
    
    public init(description: String = "<View>", id: UUID = UUID(), type: ContentData = .other, lifetime: Lifetime = .element(count: 1), isOverlay: Bool = true, initialPosition: Position = (.zero, false), initialRotation: Rotation = (.init(), false), @ViewBuilder body: () -> some View) {
        self.description = description
        self.id = id
        self.contentData = type
        self.isOverlay = isOverlay
        self.body = AnyView(body())
        
        self.initialPosition = initialPosition
        self.initialRotation = initialRotation
    }
    
    public func withParent(_ parentID: UUID) -> ViewElement {
        var copy = self
        copy.parentID = parentID
        return copy
    }
}

// @MainActor
// public struct AnchorElement: Element {
//     public var description: String = "<Anchor>"
//     public var id: UUID = UUID()
//     public var lifetime: Lifetime = .indefinite(isOver: false)
//     public var onRender: RenderEventHandler? = nil
//     public var onDisappear: RenderEventHandler? = nil
//     public var contentData: ContentData = .other
//
//     public var anchorEntity: AnchorEntity
//
//     init(position: SIMD3<Float> = .zero, rotation: EulerAngles = .init()) {
//         anchorEntity = AnchorEntity()
//         anchorEntity.setPosition(position, relativeTo: nil)
//         anchorEntity.setOrientation(simd_quatf(Rotation3D(eulerAngles: rotation)), relativeTo: nil)
//     }
// }

@MainActor
public struct EntityElement: Element, Loadable, ParentReferencingElement {
    public var entity: Entity?
    public var description: String = "<Entity>"
    public var id: UUID = UUID()
    public let contentData = ContentData.realityKitEntity
    
    private var resourceName: String?
    private var bundle: Bundle?
    
    public var onRender: RenderEventHandler? = { _ in }
    public var onDisappear: RenderEventHandler? = { _ in }
    
    public var lifetime: Lifetime = .element(count: 1)
    public var isInteractable: Bool = false
    
    public private(set) var isLoaded = true
    
    public let initialPosition: Position
    public let initialRotation: Rotation
    public let initialScale: SIMD3<Float>
    
    public var parentID: UUID? = nil

    public let fadeInOutDuration: (in: Duration, out: Duration)?
    internal var fadeInOutAnimation: (in: AnimationResource?, out: AnimationResource?) = (nil, nil)

    mutating internal func setupFade() {
        if let fadeInOutDuration {
            let opacityComponent = OpacityComponent(opacity: 0.0)
            entity?.components.set(opacityComponent)
            // entity?.components[OpacityComponent.self]?.opacity = 0
            let fadeIn = FromToByAnimation<Float>(
                name: "fadein",
                from: 0.0,
                to: 1.0,
                duration: fadeInOutDuration.in.seconds,
                timing: .easeInOut,
                bindTarget: .opacity,
                repeatMode: .none
            )
            let fadeOut = FromToByAnimation<Float>(
                name: "fadeout",
                from: 1.0,
                to: 0.0,
                duration: fadeInOutDuration.out.seconds,
                timing: .easeInOut,
                bindTarget: .opacity,
                repeatMode: .none
            )
            fadeInOutAnimation = (try? AnimationResource.generate(with: fadeIn), try? AnimationResource.generate(with: fadeOut))
        }
    }

    public init(
        entity: Entity,
        description: String = "<Entity>",
        initialPosition: Position = (.zero, false),
        initialRotation: Rotation = (EulerAngles(), false),
        lifetime: Lifetime = .element(count: 1),
        initialScale: SIMD3<Float> = .one,
        isInteractable: Bool = false,
        fadeInOutDuration: (in: Duration, out: Duration)? = nil,
        onRender: @escaping RenderEventHandler = { _ in },
        onDisappear: @escaping RenderEventHandler = { _ in }
    ) {
        self.entity = entity
        self.description = description
        self.id = UUID()
        self.initialPosition = initialPosition
        self.initialRotation = initialRotation
        self.initialScale = initialScale
        self.lifetime = lifetime
        self.onRender = onRender
        self.onDisappear = onDisappear
        self.fadeInOutDuration = fadeInOutDuration
        
        self.isInteractable = isInteractable
        
        if isInteractable {
            self.entity?.components.set(GestureComponent(canDrag: true, pivotOnDrag: true, preserveOrientationOnPivotDrag: true, canScale: true, canRotate: true))
        }

        setupFade()
    }

    public init(
        named resourceName: String,
        in bundle: Bundle? = nil,
        description: String = "<Entity>",
        initialPosition: Position = (.zero, false),
        initialRotation: Rotation = (EulerAngles(), false),
        initialScale: SIMD3<Float> = .one,
        isInteractable: Bool = false,
        lifetime: Lifetime = .element(count: 1),
        fadeInOutDuration: (in: Duration, out: Duration)? = nil,
        onRender: @escaping RenderEventHandler = { _ in },
        onDisappear: @escaping RenderEventHandler = { _ in }
    ) {
        self.resourceName = resourceName
        self.bundle = bundle
        self.description = description
        self.id = UUID()
        self.isLoaded = false
        self.lifetime = lifetime
        self.initialPosition = initialPosition
        self.initialRotation = initialRotation
        self.initialScale = initialScale
        self.onRender = onRender
        self.onDisappear = onDisappear
        self.isInteractable = isInteractable
        self.fadeInOutDuration = fadeInOutDuration
        
        if isInteractable {
            self.entity?.enableGesture()
        }
    }
    
    public func load() async throws -> EntityElement {
        if !self.isLoaded, self.entity == nil, let resourceName {
            let bundle = self.bundle ?? Fable.defaultBundle
            guard let entity = try? await Entity(named: resourceName, in: bundle) else {
                throw FileError.fileNotFound(fileName: resourceName)
            }
            var copy = self
            copy.entity = entity
            if copy.isInteractable {
                copy.entity?.enableGesture()
            }
            copy.setupFade()
            copy.isLoaded = true
            return copy
        } else {
            return self
        }
    }
    
    public func withParent(_ parentID: UUID) -> Self {
        var copy = self
        copy.parentID = parentID
        return copy
    }
}

public struct EventElement: Element {
    public let contentData: ContentData = .other
    
    public var lifetime: Lifetime = .instant
    
    public let description: String
    public let id: UUID = UUID()
    
    public var onRender: RenderEventHandler? = nil
    public var onDisappear: RenderEventHandler? = nil
    
    public init(description: String = "<Swift Function>", onRender: (@MainActor @escaping @Sendable (FableController) -> Void)) {
        self.description = description
        self.onRender = onRender
    }
}

public enum FileError: Error {
    case fileNotFound(fileName: String)
}
