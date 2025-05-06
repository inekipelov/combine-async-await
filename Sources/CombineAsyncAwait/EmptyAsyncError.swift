// Publisher+Async.swift
// Async/await extensions for Combine publishers

import Foundation

public struct EmptyAsyncError: Error, LocalizedError {
    public var errorDescription: String? {
        return "Publisher completed without producing any values"
    }
}
