
public func Mark(_ marker: MarkerType) -> Element {
    let element = Element(isEventElement: true)
    element.metadata[.isMarker] = true
    element.metadata[.markerType] = marker
    element.isNonRenderingElement = true
    return element
}

public enum MarkerType: Hashable {
    case start
}

extension Element {
    var isMarker: Bool {
        (self.metadata[.isMarker] as? Bool) ?? false
    }
    
    var markerType: MarkerType? {
        self.metadata[.markerType] as? MarkerType
    }
}
