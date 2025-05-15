import SwiftUI
import RealityKit
import AVFoundation

@resultBuilder
public struct ElementBuilder {
    public static func buildBlock(_ components: Element...) -> [Element] {
        return components
    }
    
    public static func buildBlock(_ components: [Element]...) -> [Element] {
        return components.flatMap(\.self)
    }
    
    public static func buildArray(_ components: [[Element]]) -> [Element] {
        return components.flatMap(\.self)
    }
    
    public static func buildPartialBlock(accumulated: [Element], next: Element) -> [Element] {
        return accumulated + [next]
    }
    
    public static func buildPartialBlock(accumulated: [Element], next: [Element]) -> [Element] {
        return accumulated + next
    }
    
    public static func buildPartialBlock(first: Element) -> [Element] {
        return [first]
    }
    
    public static func buildPartialBlock(first: [Element]) -> [Element] {
        return first
    }
}

extension [Element] {
    public init(@ElementBuilder builder: () -> [Element]) {
        self = builder()
    }
}

public extension Element {
    func id(_ id: UUID) -> Self {
        self.id = id
        return self
    }
    
    func onLoad(_ handler: @escaping AsyncEventHandler) -> Self {
        self.onLoad.append(handler)
        return self
    }
    
    func notifyOnLoad() -> Self {
        self.onLoad { thisElement in Task.detached { print("Loading \(thisElement.description)") } }
    }
    
    func onDidLoad(_ handler: @escaping AsyncEventHandler) -> Self {
        self.onDidLoad.append(handler)
        return self
    }
    
    func onWillRender(_ handler: @escaping RenderEventHandler) -> Self {
        self.willRender.append(handler)
        return self
    }
    
    func notifyOnWillRender() -> Self {
        self.onWillRender { thisElement, _ in Task.detached { print("Rendering \(thisElement.description)") } }
    }
    
    func onDidRender(_ handler: @escaping RenderEventHandler) -> Self {
        self.didRender.append(handler)
        return self
    }
    
    func notifyOnDidRender() -> Self {
        self.onDidRender { thisElement, _ in Task.detached { print("Rendered \(thisElement.description)") } }
    }
    
    func onWillDestroy(_ handler: @escaping AsyncEventHandler) -> Self {
        self.willDestroy.append(handler)
        return self
    }
    
    func notifyOnWillDestroy() -> Self {
        self.onWillDestroy { thisElement in Task.detached { print("Destroying \(thisElement.description)") } }
    }
    
    func worldTransform() -> Self {
        self.coordinateSpaceAnchor = .world
        return self
    }
    
    func relativeTransform() -> Self {
        self.coordinateSpaceAnchor = .parent
        return self
    }
    
    func setCoordinateSpaceAnchor(to coordinateSpaceAnchor: CoordinateSpaceAnchor) -> Self {
        self.coordinateSpaceAnchor = coordinateSpaceAnchor
        return self
    }
    
    func transform(_ transform: Transform) -> Self {
        self.transform = transform
        return self
    }
    
    func translate(_ x: Float, _ y: Float, _ z: Float) -> Self {
        self.transform.translation += .init(x: x, y: y, z: z)
        return self
    }
    
    func translate(x: Float = 0, y: Float = 0, z: Float = 0) -> Self {
        self.transform.translation += .init(x: x, y: y, z: z)
        return self
    }
    
    func translate(_ amount: SIMD3<Float>) -> Self {
        self.transform.translation += amount
        return self
    }
    
    func rotate(radians x: Float, _ y: Float, _ z: Float) -> Self {
        let currentAngles = self.transform.rotation.angles
        let addingAngles = SIMD3<Float>(x: x, y: y, z: z)
        let newAngles = currentAngles + addingAngles
        let eulerAngles = EulerAngles(angles: newAngles, order: .xyz)
        let newAngleRotation3D = Rotation3D(eulerAngles: eulerAngles)
        self.transform.rotation = simd_quatf(newAngleRotation3D)
        
        return self
    }
    
    @inlinable
    func rotate(radiansX x: Float = 0, y: Float = 0, z: Float = 0) -> Self {
        rotate(radians: x, y, z)
    }
    
    func rotate(degrees x: Float, _ y: Float, _ z: Float) -> Self {
        let currentAngles = self.transform.rotation.angles
        let addingAngles = SIMD3<Float>(x: (x / 180) * .pi, y: (y / 180) * .pi, z: (z / 180) * .pi)
        let newAngles = currentAngles + addingAngles
        let eulerAngles = EulerAngles(angles: newAngles, order: .xyz)
        let newAngleRotation3D = Rotation3D(eulerAngles: eulerAngles)
        self.transform.rotation = simd_quatf(newAngleRotation3D)
        
        return self
    }
    
    @inlinable
    func rotate(degreesX x: Float = 0, y: Float = 0, z: Float = 0) -> Self {
        rotate(degrees: x, y, z)
    }
    
    func rotate(_ angles: EulerAngles) -> Self {
        let currentAngles = self.transform.rotation.angles
        let newAngles = currentAngles + SIMD3<Float>(angles.angles)
        let eulerAngles = EulerAngles(angles: newAngles, order: .xyz)
        let newAngleRotation3D = Rotation3D(eulerAngles: eulerAngles)
        self.transform.rotation = simd_quatf(newAngleRotation3D)
        
        return self
    }
    
    func lookAt(_ point: SIMD3<Float>, upVector: SIMD3<Float>? = nil, lockLocalX: Bool = false) -> Self {
        self.onWillRender { thisElement, renderer in
            guard let entity = thisElement.realityKitEntity else { fatalError("Event elements cannot rotate.") }
            let rotationAngles = EulerAngles(angles: thisElement.transform.rotation.angles, order: .xyz)
            
            let targetPoint: SIMD3<Float>
            
            if lockLocalX {
                targetPoint = point.replacing(with: entity.scenePosition, where: SIMDMask([false, true, false]))
            } else {
                targetPoint = point
            }
            
            if let upVector {
                entity.look(at: targetPoint, from: entity.position, upVector: upVector, relativeTo: nil, forward: .positiveZ)
            } else {
                entity.look(at: targetPoint, from: entity.position, relativeTo: nil, forward: .positiveZ)
            }
            
            
            
            let afterLookAt = Rotation3D(entity.transform.rotation)
            let newRotation = afterLookAt.rotated(by: Rotation3D(eulerAngles: rotationAngles))
            entity.transform.rotation = simd_quatf(newRotation)
//            entity.setOrientation(simd_quatf(Rotation3D(eulerAngles: EulerAngles(angles: .init(0, Float.pi, 0), order: .xyz))), relativeTo: entity)
        }
    }
    
    func lookAt(element otherElement: Element, upVector: SIMD3<Float>? = nil, lockLocalX: Bool = false) -> Self {
        self.onWillRender { thisElement, renderer in
            guard let entity = thisElement.realityKitEntity else { fatalError("Event elements cannot rotate.") }
            guard let position = otherElement.realityKitEntity?.scenePosition else { fatalError("Event elements cannot be targetted for rotation.") }
            let rotationAngles = EulerAngles(angles: thisElement.transform.rotation.angles, order: .xyz)
            
            let targetPoint: SIMD3<Float>
            
            if lockLocalX {
                targetPoint = position.replacing(with: entity.scenePosition, where: SIMDMask([false, true, false]))
            } else {
                targetPoint = position
            }
            
            if let upVector {
                entity.look(at: targetPoint, from: entity.position, upVector: upVector, relativeTo: nil, forward: .positiveZ)
            } else {
                entity.look(at: targetPoint, from: entity.position, relativeTo: nil, forward: .positiveZ)
            }
            
            let afterLookAt = Rotation3D(entity.transform.rotation)
            let newRotation = afterLookAt.rotated(by: Rotation3D(eulerAngles: rotationAngles))
            entity.transform.rotation = simd_quatf(newRotation)
//            entity.setOrientation(simd_quatf(Rotation3D(eulerAngles: EulerAngles(angles: .init(0, Float.pi, 0), order: .xyz))), relativeTo: entity)
        }
    }
    
    func lookAtHead(upVector: SIMD3<Float>? = nil, lockLocalX: Bool = false) -> Self {
        self.onWillRender { thisElement, renderer in
            guard let entity = thisElement.realityKitEntity else { fatalError("Event elements cannot rotate.") }
            let rotationAngles = EulerAngles(angles: thisElement.transform.rotation.angles, order: .xyz)
            
            let targetPoint: SIMD3<Float>
            
            if lockLocalX {
                targetPoint = renderer.currentHeadPosition.replacing(with: entity.scenePosition, where: SIMDMask([false, true, false]))
            } else {
                targetPoint = renderer.currentHeadPosition
            }
            
            if let upVector {
                entity.look(at: targetPoint, from: entity.position, upVector: upVector, relativeTo: nil, forward: .positiveZ)
            } else {
                entity.look(at: targetPoint, from: entity.position, relativeTo: nil, forward: .positiveZ)
            }
            let afterLookAt = Rotation3D(entity.transform.rotation)
            let newRotation = afterLookAt.rotated(by: Rotation3D(eulerAngles: rotationAngles))
            entity.transform.rotation = simd_quatf(newRotation)
//            entity.setOrientation(simd_quatf(Rotation3D(eulerAngles: EulerAngles(angles: .init(0, Float.pi, 0), order: .xyz))), relativeTo: entity)
        }
    }
    
    func scale(_ x: Float, _ y: Float, _ z: Float) -> Self {
        self.transform.scale *= .init(x: x, y: y, z: z)
        return self
    }
    
    @inlinable
    func scale(x: Float = 0, y: Float = 0, z: Float = 0) -> Self {
        scale(x, y, z)
    }
    
    @inlinable
    func scale(_ amount: Float) -> Self {
        scale(amount, amount, amount)
    }
    
    func scale(_ amount: SIMD3<Float>) -> Self {
        self.transform.scale *= amount
        return self
    }
    
    func appear(at time: Duration) -> Self {
        self.metadata[MetadataKey.appearAt] = time
        return self
    }
    
    func appear(_ minutes: Double, _ seconds: Double, _ frames: Double) -> Self {
        self.appear(at: .minutes(minutes).seconds(seconds).frames(frames))
    }
    
    func appear(minutes: Double = 0, seconds: Double = 0, frames: Double = 0) -> Self {
        self.appear(at: .minutes(minutes).seconds(seconds).frames(frames))
    }
    
    func disappear(at time: Duration) -> Self  {
        self.metadata[MetadataKey.disappearAt] = time
        return self
    }
    
    func disappear(minutes: Double = 0, seconds: Double = 0, frames: Double = 0) -> Self {
        self.disappear(at: .minutes(minutes).seconds(seconds).frames(frames))
    }
    
    func disappear(_ minutes: Double, _ seconds: Double, _ frames: Double) -> Self {
        self.disappear(at: .minutes(minutes).seconds(seconds).frames(frames))
    }
    
    func children(@ElementBuilder builder: (Element) -> [Element]) -> Self {
        self.children.formUnion(builder(self))
        
        for child in children {
            child.parent = self
        }
        
        return self
    }
    
    func children(@ElementBuilder builder: () -> [Element]) -> Self {
        self.children.formUnion(builder())
        
        for child in children {
            child.parent = self
        }
        
        return self
    }
    
    func handleMessage(_ messageType: LifecycleMessage, _ handler: @escaping LifecycleMessageHandler) -> Self {
        self.messageHandler[messageType] = handler
        return self
    }
    
    func tag(_ key: MetadataKey, value: Any) -> Self {
        self.metadata[key] = value
        return self
    }
    
    func animate(at time: Duration, animation: AnimationResource) -> Self {
        self.eventList.append((time, { thisElement in
            self.notify("running animation - \(animation.name ?? "name unknown")")
            thisElement.realityKitEntity?.playAnimation(animation, transitionDuration: 0, startsPaused: false)
        }))
        return self
    }
    
    @MainActor
    func fadeIn(at time: Duration = .zero, duration: Duration = .seconds(1)) -> Self {
        let fadeInAnimation = FromToByAnimation<Float>(
            name: "\(self.description)-fadeIn",
            from: 0,
            to: 1,
            duration: duration.seconds,
            timing: .easeInOut,
            bindTarget: .opacity,
            repeatMode: .none
        )
        
        return self.onLoad { thisElement in
            if !thisElement.children.isEmpty {
                for childIndex in thisElement.children.indices {
                    guard thisElement.children[childIndex].metadata[.appearAt] == nil else { continue }
                    guard !thisElement.children[childIndex].isEventElement else { continue }
                    guard !thisElement.children[childIndex].isNonRenderingElement else { continue }
                    thisElement.children.update(with: thisElement.children[childIndex].fadeIn(at: time, duration: duration))
                }
            }
        }.animate(at: time, animation: try! AnimationResource.generate(with: fadeInAnimation))
    }
    
    @MainActor
    func fadeOut(at time: Duration, duration: Duration = .seconds(1)) -> Self {
        let fadeInAnimation = FromToByAnimation<Float>(
            name: "\(self.description)-fadeOut",
            from: 1,
            to: 0,
            duration: duration.seconds,
            timing: .easeInOut,
            bindTarget: .opacity,
            repeatMode: .none
        )
        return self.onLoad { thisElement in
            if !thisElement.children.isEmpty {
                for childIndex in thisElement.children.indices {
                    guard thisElement.children[childIndex].metadata[.disappearAt] == nil else { continue }
                    guard !thisElement.children[childIndex].isEventElement else { continue }
                    guard !thisElement.children[childIndex].isNonRenderingElement else { continue }
                    thisElement.children.update(with: thisElement.children[childIndex].fadeOut(at: time, duration: duration))
                }
            }
        }.animate(at: time, animation: try! AnimationResource.generate(with: fadeInAnimation))
    }
    
    @MainActor
    func fadeOut(duration: Duration = .seconds(1)) -> Self {
        let fadeOutAnimation = FromToByAnimation<Float>(
            name: "\(self.description)-fadeOut-\(self.id)",
            from: 1,
            to: 0,
            duration: duration.seconds,
            timing: .easeInOut,
            bindTarget: .opacity,
            repeatMode: .none
        )
        return self.onWillDestroy { thisElement in
            if thisElement.isDestroyed { return }
//            if ((thisElement.metadata["fadeOutHasBeenCalled"] as? Bool) ?? false) { return }
            
            let fadeOutAnimationResource = try! AnimationResource.generate(with: fadeOutAnimation)
            thisElement.realityKitEntity?.playAnimation(fadeOutAnimationResource, transitionDuration: 0, startsPaused: false)
            thisElement.notify("running fadeout animation for \(self.description)")
            thisElement.metadata["fadeOutHasBeenCalled"] = true
            try? await Task.sleep(for: duration)
        }.onLoad { thisElement in
            if !thisElement.children.isEmpty {
                for childIndex in thisElement.children.indices {
                    guard thisElement.children[childIndex].metadata[.disappearAt] == nil else { continue }
                    guard !thisElement.children[childIndex].isEventElement else { continue }
                    guard !thisElement.children[childIndex].isNonRenderingElement else { continue }
                    thisElement.children.update(with: thisElement.children[childIndex].fadeOut(duration: duration))
                }
            }
        }
    }
    
    func attach(@ViewBuilder _ attachment: @escaping () -> some View) -> Self {
        self.realityKitAttachment = AnyView(attachment())
        return self
    }
    
    @MainActor
    func interactable(canDrag: Bool = true, canScale: Bool = true, canRotate: Bool = false) -> Self {
        return self.onDidRender { thisElement, renderer in
            thisElement.realityKitEntity?.enableGesture(
                canDrag: canDrag,
                pivotOnDrag: false,
                canScale: canScale,
                canRotate: canRotate
            )
        }
    }
    
    func proceedAfterDestroy(waiting delay: Duration) -> Self {
        self.onWillDestroy { thisElement in
            Task {
                try? await Task.sleep(for: delay)
                thisElement.controllerContext.next()
            }
        }
    }
    
    func startMediaFrom(time: CMTime) -> Self {
        self.onWillRender { thisElement, renderer in
            (self.metadata["avPlayer"] as? AVPlayer)!.seek(to: time, toleranceBefore: .init(seconds: 0.1, preferredTimescale: 60), toleranceAfter: .init(seconds: 0.1, preferredTimescale: 60))
        }
    }
    
    func startMediaFrom(minutes: Double, seconds: Double, frames: Double) -> Self {
        let duration: Duration = .minutes(minutes).seconds(seconds).frames(frames)
        let time = duration.cmTime
        return self.startMediaFrom(time: time)
    }
    
    #if DEBUG
    func debug() -> Self {
        self.debugMode = true
        return self
    }
    #endif
}
