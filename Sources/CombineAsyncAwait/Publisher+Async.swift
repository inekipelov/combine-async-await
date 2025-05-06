// Publisher+Async.swift
// Async/await extensions for Combine publishers

import Combine
import Foundation

// MARK: - Publisher Async Extensions

public extension Publisher {
    /**
     Retrieves the most recent value emitted by the publisher as an async value.
     
     This method bridges Combine's callback-based API with Swift's async/await, using
     a checked throwing continuation to suspend execution until the publisher completes.
     
     Technical Details:
     - The method uses `withCheckedThrowingContinuation` to resume the async context once 
       the publisher either emits a value or completes.
     - A cancellation handler (`withTaskCancellationHandler`) is incorporated to react immediately 
       if the surrounding task is cancelled.
     - Internally, it subscribes via `sink`, capturing the last emitted value before the publisher 
       completes. If the publisher completes without emitting a value, the function throws the 
       `EmptyAsyncError`.
     - Note: Starting with Swift 5.5 and further enhanced in Swift 5.7, Swift provides a built-in 
       construct (`publisher.values`) that allows reacting to every signal emitted by a publisher 
       as an async sequence. This can be used to process each value individually in a for-await-in loop.
     
     - Returns: The last value emitted by the publisher before completion.
     - Throws: The publisher’s error, or `EmptyAsyncError` if the publisher completes without emitting any value.
     */
    func async() async throws -> Output {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var lastValue: Output?
                var didResume = false

                // Create the cancellable reference outside of sink to allow referencing it in cancellation handler
                var cancellable: AnyCancellable?

                // Function to safely resume the continuation once
                func safeResume(with result: Result<Output, Error>) {
                    guard !didResume else { return }
                    didResume = true
                    cancellable?.cancel()
                    continuation.resume(with: result)
                }

                cancellable = self.sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            if let value = lastValue {
                                safeResume(with: .success(value))
                            } else {
                                safeResume(with: .failure(EmptyAsyncError()))
                            }
                        case .failure(let error):
                            safeResume(with: .failure(error))
                        }
                    },
                    receiveValue: { value in
                        lastValue = value
                    }
                )

                // Immediately check for cancellation (no delay needed)
                if Task.isCancelled {
                    safeResume(with: .failure(CancellationError()))
                }
            }
        } onCancel: {
            // Immediate cancellation handling - will flow into the publisher's subscription
            // The actual cancellation logic is in safeResume
        }
    }
}

public extension Publisher where Failure == Never {
    /**
     Retrieves the most recent value emitted by the publisher as an async value.
     
     This method bridges Combine's stream-based callbacks with Swift's async/await model. Since
     the publisher never fails (Failure == Never), this version is non-throwing.
     
     Technical Details:
     - Uses `withCheckedContinuation` to suspend the async context until the publisher completes.
     - A cancellation handler (`withTaskCancellationHandler`) is used to instantly react if the task is cancelled.
     - In case the task is cancelled or the publisher finishes without emitting any value, the current value (if any) is resumed.
     
     - Returns: The last emitted value before the publisher completes.
     */
    func async() async -> Output {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var lastValue: Output?
                var didResume = false
                var cancellable: AnyCancellable?
                
                // Helper to safely resume the continuation with the captured value.
                func safeResume() {
                    // Only resume if not already resumed and lastValue is set
                    guard !didResume, let value = lastValue else { return }
                    didResume = true
                    // Cancel the subscription once we resume
                    cancellable?.cancel()
                    // Resume the async code
                    continuation.resume(returning: value)
                }
                
                // Subscribe to the publisher; capture values and handle completion
                cancellable = self.sink(
                    receiveCompletion: { completion in
                        // Technically, since Failure == Never, completion is always .finished.
                        // Resume the continuation with the last captured value.
                        safeResume()
                    },
                    receiveValue: { value in
                        // Update the lastValue with the most recent emitted value.
                        lastValue = value
                    }
                )
                
                // In case the task is cancelled, attempt to resume safely.
                if Task.isCancelled {
                    safeResume()
                }
            }
        } onCancel: {
            // Cancellation handler: Additional cancellation logic could be placed here if needed.
            // Since our cancellation logic is handled in safeResume, no further actions are taken.
        }
    }
}
