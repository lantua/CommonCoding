//
//  File.swift
//  
//
//  Created by Natchanon Luangsomboon on 9/9/2563 BE.
//

public struct CodingContext<Shared> {
    public var shared: Shared, userInfo: [CodingUserInfoKey: Any], path: CodingPath

    public init(_ shared: Shared, userInfo: [CodingUserInfoKey: Any], path: CodingPath = .root) {
        self.shared = shared
        self.userInfo = userInfo
        self.path = path
    }

    public func appending(_ key: CodingKey) -> Self {
        .init(shared, userInfo: userInfo, path: .child(key: key, parent: path))
    }

    public func error(_ description: String = "", error: Error? = nil) -> DecodingError.Context {
        .init(codingPath: path.expanded, debugDescription: description, underlyingError: error)
    }
    public func error(_ description: String = "", error: Error? = nil) -> EncodingError.Context {
        .init(codingPath: path.expanded, debugDescription: description, underlyingError: error)
    }

}

public protocol ContextContainer {
    associatedtype Shared
    var context: CodingContext<Shared> { get }
}
public extension ContextContainer {
    var userInfo: [CodingUserInfoKey: Any] { context.userInfo }
    var codingPath: [CodingKey] { context.path.expanded }
}

