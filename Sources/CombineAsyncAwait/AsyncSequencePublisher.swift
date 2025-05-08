// Publisher+Async.swift
// Async/await extensions for Combine publishers

import Combine
import Foundation

/// A publisher that emits elements from an AsyncSequence
public struct AsyncSequencePublisher<S: AsyncSequence>: Publisher where S.Element: Sendable, S: Sendable {
    public typealias Output = S.Element
    public typealias Failure = Error

    private let sequence: S

    /// Initializes a publisher that emits elements from the given AsyncSequence
    /// - Parameter sequence: The AsyncSequence to publish
    public init(_ sequence: S) {
        self.sequence = sequence
    }

    public func receive<Sink: Subscriber>(subscriber: Sink) where Sink.Input == Output, Sink.Failure == Failure {
        let subscription = SequenceSubscription(subscriber: subscriber, sequence: sequence)
        subscriber.receive(subscription: subscription)
    }
}

private extension AsyncSequencePublisher {
    final class SequenceSubscription<Sink: Subscriber, Seq: AsyncSequence>: Subscription where Sink.Input == Seq.Element, Sink.Failure == Error {
        private var subscriber: Sink?
        private var task: Task<Void, Never>?
        private let lock = NSLock()
        private var demand: Subscribers.Demand = .none
        private let sequence: Seq
        
        init(subscriber: Sink, sequence: Seq) {
            self.subscriber = subscriber
            self.sequence = sequence
            
            // Start the task after initialization to avoid object capture issues
            setupAsyncSequenceSubscription()
        }
        
        private func setupAsyncSequenceSubscription() {
            // Create an asynchronous task that will receive elements from AsyncSequence
            // and deliver them to the Combine subscriber with proper backpressure handling
            task = Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    // Iterate through all elements of AsyncSequence
                    // AsyncSequence is a data source that may be slow or asynchronous
                    for try await element in sequence {
                        // Check for task cancellation to exit the loop quickly
                        if Task.isCancelled {
                            break
                        }
                        
                        // Safely get current values of subscriber and demand
                        // using lock to prevent race conditions
                        let (currentSubscriber, currentDemand) = self.lock.withLock {
                            (self.subscriber, self.demand)
                        }
                        
                        guard let subscriber = currentSubscriber else { return }
                        
                        if currentDemand > .none {
                            // If there's demand for elements, decrease the counter
                            // and deliver the element to the subscriber
                            self.lock.withLock {
                                self.demand -= 1
                            }
                            
                            // Deliver the element to the subscriber and get new demand
                            let newDemand = subscriber.receive(element)
                            
                            // Update total demand with the new value
                            self.lock.withLock {
                                self.demand += newDemand
                            }
                        } else {
                            // Backpressure mechanism implementation:
                            // If the subscriber is not ready to receive data (demand = 0),
                            // wait until demand appears using exponential backoff strategy
                            var sleepTime: UInt64 = 1_000_000 // Start with 1ms delay
                            let maxRetries = 10 // Limit the number of retries
                            var retryCount = 0
                            
                            while !Task.isCancelled && retryCount < maxRetries {
                                // Check if demand has appeared
                                let hasDemand = self.lock.withLock { self.demand > .none }
                                if hasDemand { break }
                                
                                // Wait with maximum delay cap at 50ms
                                try await Task.sleep(nanoseconds: Swift.min(sleepTime, 50_000_000))
                                sleepTime *= 2 // Increase wait time exponentially
                                retryCount += 1
                            }
                            
                            if Task.isCancelled { break }
                        }
                    }
                    
                    // If AsyncSequence completed successfully, notify the subscriber
                    self.lock.withLock {
                        self.subscriber?.receive(completion: .finished)
                    }
                } catch {
                    // If an error occurred in AsyncSequence, pass it to the subscriber
                    self.lock.withLock {
                        self.subscriber?.receive(completion: .failure(error))
                    }
                }
            }
        }

        func request(_ newDemand: Subscribers.Demand) {
            lock.withLock {
                demand += newDemand
            }
        }

        func cancel() {
            task?.cancel()
            lock.withLock {
                subscriber = nil
            }
        }
    }
}

/// Extension to make any AsyncSequence available as a Combine Publisher
public extension AsyncSequence where Element: Sendable, Self: Sendable {
    /// Returns a publisher that emits elements from this AsyncSequence
    public var publisher: AsyncSequencePublisher<Self> {
        AsyncSequencePublisher(self)
    }
}
