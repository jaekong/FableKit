import Foundation
import RealityKit
import SwiftUI

@MainActor
public func Skysphere(_ url: URL, diameter: Float = 1000, hasDirectionalLight: Bool = true) -> Element {
    let element = Element()
        .onLoad { thisElement in
            guard let texture = try? await TextureResource(contentsOf: url, options: .init(semantic: .hdrColor, compression: .default)) else { fatalError("Texture not found in \(url.absoluteString)")}
            
            let mesh = MeshResource.generateSphere(radius: diameter)
            var material = UnlitMaterial(texture: texture)
            material.faceCulling = .front
            
            let entity = ModelEntity(mesh: mesh, materials: [material])
            
            if hasDirectionalLight {
                let directionalLight = DirectionalLightComponent()
                entity.components.set(directionalLight)
            }
            
            thisElement.realityKitEntity = entity
        }
//        .onWillRender { thisElement, _ in
//            thisElement.metadata["previousImmersionStyle"] = thisElement.controllerContext.immersionStyle
//            thisElement.controllerContext.immersionStyle = .full
//        }
//        .onWillDestroy { thisElement in
//            thisElement.controllerContext.immersionStyle = thisElement.metadata["previousImmersionStyle"] as? (any ImmersionStyle) ?? .mixed
//        }
        .worldTransform()
        .translate(0, 0, 0)
    
    return element
}

@MainActor
public func Skysphere(_ name: String, withExtension fileExtension: String? = nil, in bundle: Bundle = FableController.defaultBundle, diameter: Float = 1000, hasDirectionalLight: Bool = true) -> Element {
    guard let url = bundle.url(forResource: name, withExtension: fileExtension) else { fatalError("No skybox texture named \(name) in bundle.")}
    return Skysphere(url, diameter: diameter, hasDirectionalLight: hasDirectionalLight)
}

@MainActor
public func Skysphere(_ color: Color, diameter: Float = 1000, hasDirectionalLight: Bool = true) -> Element {
    let element = Element()
        .onLoad { thisElement in
            let mesh = MeshResource.generateSphere(radius: diameter)
            var material = UnlitMaterial(color: UIColor(color))
            material.faceCulling = .front
            
            let entity = ModelEntity(mesh: mesh, materials: [material])
            
            if hasDirectionalLight {
                let directionalLight = DirectionalLightComponent()
                entity.components.set(directionalLight)
            }
            
            thisElement.realityKitEntity = entity
        }
//        .onWillRender { thisElement, _ in
//            thisElement.metadata["previousImmersionStyle"] = thisElement.controllerContext.immersionStyle
//            thisElement.controllerContext.immersionStyle = .full
//        }
//        .onWillDestroy { thisElement in
//            thisElement.controllerContext.immersionStyle = thisElement.metadata["previousImmersionStyle"] as? (any ImmersionStyle) ?? .mixed
//        }
        .worldTransform()
        .translate(0, 0, 0)
    
    return element
}
