import Foundation
import RealityKit

@MainActor
public func Scene(_ url: URL) -> Element {
    let element = Element()
        .onLoad { thisElement in
            guard let entity = try? await Entity(contentsOf: url) else { fatalError("No scene file found at \(url.absoluteString)") }
            
            thisElement.realityKitEntity = entity
        }
        .tag(.description, value: url.absoluteString)
    
    return element
}

@MainActor
public func Scene(_ name: some CustomStringConvertible, in bundle: Bundle? = nil) -> Element {
    let element = Element()
        .onLoad { thisElement in
            guard let entity = try? await Entity(named: name.description, in: bundle ?? thisElement.defaultBundle) else { fatalError("No scene file named \(name) found.") }
            
            thisElement.realityKitEntity = entity
        }
        .tag(.description, value: "Scene: \(name)")
    
    return element
}
