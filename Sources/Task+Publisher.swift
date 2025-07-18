// Task+Publisher.swift
// Task extensions for Combine publishers

import Combine
import Foundation

// MARK: - Task to Publisher conversion

public extension Task where Failure == Never {
    /// Convert a non-throwing Task to a Publisher that never fails
    /// - Returns: A publisher that emits the task's result and then completes
    var publisher: Future<Success, Never> {
        Future<Success, Never> { promise in
            let currentTask = self

            Task {
                let result = await currentTask.value
                promise(.success(result))
                return result
            }
        }
    }
}

public extension Task where Failure == Error {
    /// Convert a throwing Task to a Publisher that can fail
    /// - Returns: A publisher that emits the task's result or fails with the task's error
    var publisher: Future<Success, Error> {
        Future<Success, Error> { promise in
            let currentTask = self
            
            Task {
                do {
                    let result = try await currentTask.value
                    promise(.success(result))
                    return result
                } catch {
                    promise(.failure(error))
                    throw error
                }
            }
        }
    }
}

// MARK: - Convenience Task creation methods

public extension Task where Failure == Never {
    /// Create a Task and immediately convert it to a Publisher
    /// - Parameter operation: The async operation to perform
    /// - Returns: A publisher that emits the operation's result
    static func publisher(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async -> Success
    ) -> Future<Success, Never> {
        Future<Success, Never> { promise in
            Task(priority: priority) {
                let result = await operation()
                promise(.success(result))
                return result
            }
        }
    }
}

public extension Task where Failure == Error {
    /// Create a throwing Task and immediately convert it to a Publisher
    /// - Parameter operation: The async operation to perform that can throw
    /// - Returns: A publisher that emits the operation's result or fails
    static func publisher(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async throws -> Success
    ) -> Future<Success, Error> {
        Future<Success, Error> { promise in
            Task(priority: priority) {
                do {
                    let result = try await operation()
                    promise(.success(result))
                    return result
                } catch {
                    promise(.failure(error))
                    throw error
                }
            }
        }
    }
}
