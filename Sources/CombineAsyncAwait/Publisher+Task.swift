// Publisher+Task.swift
// Task-based subscription extensions for Combine publishers

import Combine
import Foundation

// MARK: - Task-style sink

public extension Publisher {
    /// Subscription with async handling, including completion
    func task(
        priority: TaskPriority? = nil,
        receiveCompletion: @escaping @Sendable (Subscribers.Completion<Failure>) async -> Void = { _ in },
        receiveValue: @escaping @Sendable (Output) async -> Void
    ) -> AnyCancellable {
        sink(
            receiveCompletion: { completion in
                Task(priority: priority) {
                    await receiveCompletion(completion)
                }
            },
            receiveValue: { value in
                Task(priority: priority) {
                    await receiveValue(value)
                }
            }
        )
    }
}
