import RealityKit

@MainActor
public func Group(@ElementBuilder children: () -> [Element]) -> Element {
    let element = Element().children(builder: children)
        .tag(.description, value: "Group Element")
//    element.realityKitEntity?.components.set(OpacityComponent())
    return element
}
