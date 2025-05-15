public func Proceed() -> Element {
    Event().onDidRender { thisElement, _ in
        thisElement.controllerContext.next()
    }
}
