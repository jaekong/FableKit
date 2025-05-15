import Foundation

public enum MetadataKey: Hashable, ExpressibleByStringLiteral {
    case appearAt
    case disappearAt
    
    case description
    
    case boundaryTimeObservers
    
    case isMarker
    case markerType
    
    case arbitrary(String)
    
    public init(stringLiteral value: StringLiteralType) {
        self = .arbitrary(value)
    }
}
