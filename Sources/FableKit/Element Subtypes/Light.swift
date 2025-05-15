import Foundation
import RealityKit
import UIKit

@MainActor
public func DirectionalLight(color: UIColor = .white, intensity: Float = 2145.7078) -> Element {
    let element = Element()
        .onLoad { thisElement in
            let entity = Entity()
            let directionalLight = DirectionalLightComponent(color: color, intensity: intensity)
            entity.components.set(directionalLight)
            
            thisElement.realityKitEntity = entity
        }
        .worldTransform()
        .translate(0, 0, 0)
    
    return element
}

@MainActor
public func PointLight(color: UIColor = .white, intensity: Float = 26963.76, attenuationRadius: Float = 10, attenuationFalloffExponent: Float = 2) -> Element {
    let element = Element()
        .onLoad { thisElement in
            let entity = Entity()
            let pointLight = PointLightComponent(color: color, intensity: intensity, attenuationRadius: attenuationRadius, attenuationFalloffExponent: attenuationFalloffExponent)
            entity.components.set(pointLight)
            
            thisElement.realityKitEntity = entity
        }
    
    return element
}
