import RealityKit
import SwiftUI

public func Surroundings(brightness: Double) -> Element {
    let element =
        Element(isEventElement: true)
            .onDidRender { thisElement, renderer in
                Task { @MainActor in
                    thisElement.notify("adjusting environment brightness \(brightness)")
                    renderer.surroundingsEffect = .dim(intensity: brightness)
                    renderer.updateView()
                    thisElement.notify("adjusted environment surroundings effect \(String(describing: renderer.surroundingsEffect))")
                }
            }
            .tag(.description, value: "Brightness: \(brightness)")
    return element
}

@MainActor
public func Surroundings(effect: SurroundingsEffect) -> Element {
    let element =
        Element(isEventElement: true)
            .onDidRender { thisElement, renderer in
                Task { @MainActor in
                    thisElement.notify("adjusting environment surroundings \(effect)")
                    renderer.surroundingsEffect = effect
                    renderer.updateView()
                    thisElement.notify("adjusted environment surroundings effect \(String(describing: renderer.surroundingsEffect))")
                }
            }
            .tag(.description, value: "Surroundings Effect: \(effect)")
    return element
}
