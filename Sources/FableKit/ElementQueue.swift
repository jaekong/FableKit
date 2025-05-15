import Foundation

public actor ElementQueue {
    var elementsToAdd: Set<Element> = []
    
    func add(_ element: Element) {
        elementsToAdd.insert(element)
    }
}
