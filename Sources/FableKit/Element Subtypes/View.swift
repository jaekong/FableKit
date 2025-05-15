import SwiftUI

@MainActor
public func View(@ViewBuilder content: @escaping () -> some View) -> Element {
    let element = Element()
        .attach {
            content()
        }
        .tag(.description, value: "View")
    return element
}
