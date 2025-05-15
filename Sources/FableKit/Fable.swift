import SwiftUI

@Observable
@MainActor
public final class Fable: Sendable, Identifiable {
    @ObservationIgnored var elements: [Element]
    var renderedElements: [Element] {
        elements.filter { !$0.isNonRenderingElement }
    }
    @ObservationIgnored var elementBuilder: (UUID) -> [Element]
    
    @ObservationIgnored var nextIndex: Int = 0
    
    public internal(set) var isReady: Bool = false
    
    public let id: UUID
    
    public var controllerContext: FableController? {
        FableController[for: self.id]
    }
    
    public init(defaultBundle: Bundle = .main, @ElementBuilder elements: @escaping (UUID) -> [Element]) {
        FableController.defaultBundle = defaultBundle
        
        self.id = UUID()
        
        self.elements = elements(self.id)
        self.elementBuilder = elements
        self.nextIndex = findStartIndex()
        Task { [self] in
            
            for element in self.elements {
                await element.load()
                element.isRoot = true
            }
            
            self.isReady = true
        }
    }
    
    public func next() -> Element? {
        guard nextIndex <= (renderedElements.endIndex - 1) else { return nil }
        
        defer { nextIndex += 1 }
        return renderedElements[nextIndex]
    }
    
    public func reset() async {
        self.isReady = false
        self.elements = elementBuilder(self.id)
        self.nextIndex = findStartIndex()
        
        for element in self.elements {
            await element.load()
            element.isRoot = true
        }
        
        self.isReady = true
    }
    
    private func findStartIndex() -> Int {
        let startIndex = self.elements.filter { !($0.isNonRenderingElement && $0.markerType != .start) }.firstIndex { $0.isNonRenderingElement && $0.markerType == .start }
        return startIndex ?? 0
    }
}
