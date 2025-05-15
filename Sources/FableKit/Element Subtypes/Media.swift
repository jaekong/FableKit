import SwiftUI
import RealityKit
import AVFoundation

@MainActor
public func Media(_ url: URL, endAction: MediaEndAction = .proceed) -> Element {
    let entity = Entity()
    let avPlayer = AVPlayer()
    let playerItem = AVPlayerItem(url: url)
    let videoPlayerComponent = VideoPlayerComponent(avPlayer: avPlayer)
    avPlayer.replaceCurrentItem(with: playerItem)
    entity.components.set(videoPlayerComponent)
    
    let element =
        Element(entity: entity, selfTimeKeeping: true)
            .tag("avPlayer", value: avPlayer)
            .tag("playerItem", value: playerItem)
            .tag(.description, value: url.absoluteString)
            .onLoad { thisElement in
                if (try? await playerItem.asset.loadTracks(withMediaType: .video)) == nil {
                    thisElement.transform.scale = .zero
                }
                
                thisElement.metadata["didPlayToEndTimeNotification"] =  NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: playerItem).sink { _ in
                    Task {
                        switch endAction {
                            case .proceed:
                                thisElement.setAliveStatus(false)
                                thisElement.rendererContext?.updateView()
                                await thisElement.controlChannel.send(.next)
                            case .remove:
                                thisElement.setAliveStatus(false)
                                thisElement.rendererContext?.updateView()
                            default:
                                break
                        }
                    }
                }
            }
            .onWillRender { thisElement, renderer in
                if let parent = thisElement.parent {
                    thisElement.realityKitEntity?.setParent(parent.realityKitEntity)
                }
            }
            .onDidRender { thisElement, renderer in
                var boundaryTimeObservers = [Any]()
                
                let lifecycleQueue = DispatchQueue(label: thisElement.id.uuidString)
                
                for child in thisElement.children {
                    if let inTime = child.metadata[MetadataKey.appearAt] as? Duration {
                        if inTime < .instantThreshold {
                            renderer.add(element: child)
                        } else {
                            let observer = avPlayer.addBoundaryTimeObserver(forTimes: [inTime.nsValue], queue: lifecycleQueue) { [unowned child] in
                                Task { @MainActor in
                                    renderer.add(element: child)
                                }
                            }
                            boundaryTimeObservers.append(consume observer)
                        }
                    } else {
                        renderer.add(element: child)
                    }
                    
                    if let outTime = child.metadata[MetadataKey.disappearAt] as? Duration {
                        let observer = avPlayer.addBoundaryTimeObserver(forTimes: [outTime.nsValue], queue: lifecycleQueue) { [unowned child] in
                            Task { @MainActor in
                                renderer.remove(element: child)
                            }
                        }
                        boundaryTimeObservers.append(consume observer)
                    }
                }
                
                for event in thisElement.eventList {
                    if event.time < .instantThreshold {
                        Task { @MainActor in await event.handler(thisElement) }
                    } else {
                        let observer = avPlayer.addBoundaryTimeObserver(forTimes: [event.time.nsValue], queue: lifecycleQueue) { [unowned thisElement] in
                            Task { @MainActor in await event.handler(thisElement) }
                        }
                        boundaryTimeObservers.append(consume observer)
                    }
                }

                thisElement.metadata[.boundaryTimeObservers] = consume boundaryTimeObservers
                thisElement.metadata["lifecycleQueue"] = consume lifecycleQueue
                
                (thisElement.metadata["avPlayer"] as? AVPlayer)!.play()
            }
            .onWillDestroy { thisElement in
                avPlayer.pause()
                avPlayer.replaceCurrentItem(with: nil)
            }
            .handleMessage(.freeze) { message, _ in
                avPlayer.pause()
            }
            .handleMessage(.unfreeze) { message, _ in
                avPlayer.play()
            }
    
    return consume element
}

@MainActor
public func Media(_ name: String, withExtension fileExtension: String? = nil, in bundle: Bundle = FableController.defaultBundle, endAction: MediaEndAction = .proceed) -> Element {
    guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
        fatalError("No media named \(name) in \(bundle.resourceURL!)")
    }
    return Media(url, endAction: endAction).tag(.description, value: "Media: \(name)")
}

extension AVAssetTrack: @retroactive @unchecked Sendable {}

extension Duration {
    static var instantThreshold: Duration {
        .frames(3, fps: 60)
    }
}

public enum MediaEndAction {
    case proceed
    case remove
    case none
}
