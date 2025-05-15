import Logging
import Foundation

public struct UserDefaultsLogHandler: LogHandler {
    public subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set(newValue) {
            metadata[metadataKey] = newValue
        }
    }
    
    public var metadata = Logger.Metadata()
    
    public var logLevel = Logger.Level.info
    
    public var store: [String] {
        get {
            UserDefaults.standard.array(forKey: "logs") as? [String] ?? []
        }
        
        nonmutating set {
            UserDefaults.standard.set(newValue, forKey: "logs")
        }
    }
    
    private func mergedMetadata(_ metadata: Logger.Metadata?) -> Logger.Metadata {
        if let metadata = metadata {
            return self.metadata.merging(metadata, uniquingKeysWith: { _, new in new })
        } else {
            return self.metadata
        }
    }
    
    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        store.append("\(Date().ISO8601Format()) " + message.description)
    }
}
