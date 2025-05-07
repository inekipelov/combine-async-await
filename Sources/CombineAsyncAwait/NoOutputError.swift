// Publisher+Async.swift
// Async/await extensions for Combine publishers

import Foundation

/// An error indicating that a Combine publisher completed without producing any values.
/// This error is used in async/await extensions for Combine publishers to signal that
/// no output was emitted despite expectations to receive at least one result.
public struct NoOutputError: Error, LocalizedError {
    /// A localized description of the error.
    public var errorDescription: String? {
        return "Publisher completed without producing any values"
    }
}
