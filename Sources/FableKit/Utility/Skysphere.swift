import RealityKit
import Foundation

//public struct Skysphere: Element, Loadable {
//    public var entity: Entity
//    public var texture: TextureResource?
//    public var description: String = "<Skysphere>"
//    public var id = UUID()
//    public let contentData = ContentData.realityKitEntity
//    
//    public var onRender: RenderEventHandler? = { _ in }
//    public var onDisappear: RenderEventHandler? = { _ in }
//    
//    public var lifetime: Lifetime
//    
//    public private(set) var isLoaded = false
//    
//    public init(textureName: String, lifetime: Lifetime = .indefinite(isOver: false)) {
//        self.entity = Entity()
//        self.texture = TextureResource(named: textureName)
//        self.lifetime = lifetime
//    }
//    
////    public func load()
//}

@MainActor
public func Skysphere(_ textureName: String) -> EntityElement {
    let texture = try! TextureResource.load(named: textureName, in: Fable.defaultBundle)
    
    let mesh = MeshResource.generateSphere(radius: 500)
    var material = UnlitMaterial(texture: texture)
    material.faceCulling = .front
    
    let entity = ModelEntity(mesh: mesh, materials: [material])
    
    return EntityElement(entity: entity, description: "<Skysphere>", initialPosition: (.zero, AnchorType.world), lifetime: .indefinite(isOver: false), initialScale: .one, isInteractable: false, fadeInOutDuration: (.seconds(1), .seconds(1)))
}
