//
//  Errors.swift
//  
//
//  Created by Natchanon Luangsomboon on 18/2/2563 BE.
//

import Foundation

enum BinaryDecodingError: Error {
    case invalidVSUI, invalidString, invalidTag, invalidStringMapIndex
    case emptyFile, invalidFileVersion, containerTooSmall
}

extension DecodingContext {
    func error(_ description: String = "", error: Error? = nil) -> DecodingError.Context {
        .init(codingPath: codingPath, debugDescription: description, underlyingError: error)
    }
}
