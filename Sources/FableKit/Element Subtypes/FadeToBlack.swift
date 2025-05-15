
@MainActor
public func FadeToBlack(duration: Duration = .seconds(1)) -> Element {
    return Group {
        Skysphere(.black)
        Surroundings(effect: .ultraDark)
        Proceed().appear(at: duration + .seconds(1))
    }
    .fadeIn(duration: duration)
}

@MainActor
public func FadeFromBlack(duration: Duration = .seconds(1)) -> Element {
    return Group {
        Skysphere(.black)
        Surroundings(effect: .ultraDark)
        Proceed().appear(at: duration + .seconds(1))
    }
    .fadeOut(duration: duration)
}
