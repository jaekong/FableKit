import AVFoundation

public func Pause(media element: Element) -> Element {
    Event()
        .onLoad { _ in
            if element.metadata["avPlayer"] == nil {
                fatalError("Pause requires a Media element.")
            }
        }
        .onWillRender { [unowned element] _,_ in (element.metadata["avPlayer"] as? AVPlayer)?.pause() }
}
