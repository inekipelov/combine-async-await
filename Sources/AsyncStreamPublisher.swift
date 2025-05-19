// AsyncStreamPublisher.swift
// Async/await extensions for Combine publishers

import Combine
import Foundation

/// A publisher that emits elements from an AsyncStream or AsyncThrowingStream
public struct AsyncStreamPublisher<Element: Sendable, Failure: Error>: Publisher where Element: Sendable {
    public typealias Output = Element
    
    private let streamHandler: StreamHandler
    
    /// Initializes a publisher that emits elements from the given AsyncStream
    /// - Parameter stream: The AsyncStream to publish
    public init(_ stream: AsyncStream<Element>) {
        self.streamHandler = NonThrowingStreamHandler(stream: stream)
    }
    
    /// Initializes a publisher that emits elements from the given AsyncThrowingStream
    /// - Parameter stream: The AsyncThrowingStream to publish
    public init(_ stream: AsyncThrowingStream<Element, Error>) where Failure == Error {
        self.streamHandler = ThrowingStreamHandler(stream: stream)
    }
    
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let subscription = AsyncStreamSubscription(subscriber: subscriber, streamHandler: streamHandler)
        subscriber.receive(subscription: subscription)
    }
}

private extension AsyncStreamPublisher {
    // Define result enum to handle completion case
    enum StreamResult<Value, Error> {
        case success(Value)
        case failure(Error)
        case completion
    }
    
    // Base protocol for handling different stream types
    class StreamHandler {
        func startTask(handler: @escaping (StreamResult<Element, Failure>) -> Void) -> Task<Void, Never> {
            fatalError("Must be implemented by subclass")
        }
    }
    
    // Handler for non-throwing AsyncStream
    final class NonThrowingStreamHandler: StreamHandler {
        private let stream: AsyncStream<Element>
        
        init(stream: AsyncStream<Element>) {
            self.stream = stream
        }
        
        override func startTask(handler: @escaping (StreamResult<Element, Failure>) -> Void) -> Task<Void, Never> {
            return Task {
                for await element in stream {
                    handler(.success(element))
                    if Task.isCancelled { break }
                }
                // Stream completed normally, send completion notification
                handler(.completion)
            }
        }
    }
    
    // Handler for throwing AsyncThrowingStream
    final class ThrowingStreamHandler: StreamHandler {
        private let stream: AsyncThrowingStream<Element, Error>
        
        init(stream: AsyncThrowingStream<Element, Error>) {
            self.stream = stream
        }
        
        override func startTask(handler: @escaping (StreamResult<Element, Failure>) -> Void) -> Task<Void, Never> {
            return Task {
                do {
                    for try await element in stream {
                        handler(.success(element))
                        if Task.isCancelled { break }
                    }
                    // Stream completed normally, send completion notification
                    handler(.completion)
                } catch {
                    handler(.failure(error as! Failure))
                }
            }
        }
    }
    
    final class AsyncStreamSubscription<S: Subscriber>: Subscription where S.Input == Element, S.Failure == Failure {
        private var subscriber: S?
        private var task: Task<Void, Never>?
        private let lock = NSLock()
        private var pendingDemand: Subscribers.Demand = .none
        private var buffer: [Element] = []
        private let streamHandler: StreamHandler
        
        init(subscriber: S, streamHandler: StreamHandler) {
            self.subscriber = subscriber
            self.streamHandler = streamHandler
            setupStream()
        }
        
        private func setupStream() {
            task = streamHandler.startTask { [weak self] result in
                guard let self = self else { return }
                
                self.lock.withLock {
                    switch result {
                    case .success(let element):
                        self.processReceivedElement(element)
                    case .failure(let error):
                        self.processError(error)
                    case .completion:
                        self.processCompletion()
                    }
                }
            }
        }
        
        private func processReceivedElement(_ element: Element) {
            // Called with lock held
            if pendingDemand > 0 {
                deliverElement(element)
            } else {
                buffer.append(element)
            }
        }
        
        private func deliverElement(_ element: Element) {
            // Called with lock held
            pendingDemand -= 1
            
            let localSubscriber = subscriber
            // Release lock before calling out to subscriber
            lock.unlock()
            
            var additionalDemand: Subscribers.Demand = .none
            if let subscriber = localSubscriber {
                additionalDemand = subscriber.receive(element)
            }
            
            lock.lock()
            pendingDemand += additionalDemand
            
            // Process any buffered elements if we have demand
            processBufferedElementsIfNeeded()
        }
        
        private func processBufferedElementsIfNeeded() {
            // Called with lock held
            while !buffer.isEmpty && pendingDemand > 0 {
                let element = buffer.removeFirst()
                deliverElement(element)
            }
        }
        
        private func processError(_ error: Failure) {
            // Called with lock held
            let localSubscriber = subscriber
            
            // Clean up resources early
            subscriber = nil
            buffer.removeAll()
            
            // Release lock before calling out to subscriber
            lock.unlock()
            
            localSubscriber?.receive(completion: .failure(error))
            
            // Reacquire lock for consistency
            lock.lock()
        }
        
        private func processCompletion() {
            // Called with lock held
            let localSubscriber = subscriber
            
            // Clean up resources early
            subscriber = nil
            buffer.removeAll()
            
            // Release lock before calling out to subscriber
            lock.unlock()
            
            localSubscriber?.receive(completion: .finished)
            
            // Reacquire lock for consistency
            lock.lock()
        }
        
        func request(_ newDemand: Subscribers.Demand) {
            lock.withLock {
                pendingDemand += newDemand
                
                if !buffer.isEmpty {
                    processBufferedElementsIfNeeded()
                }
            }
        }
        
        func cancel() {
            task?.cancel()
            lock.withLock {
                subscriber = nil
                buffer.removeAll()
            }
        }
    }
}

// MARK: - AsyncStream Extensions

public extension AsyncStream where Element: Sendable {
    /// Returns a publisher that emits elements from this AsyncStream
    var publisher: AsyncStreamPublisher<Element, Never> {
        AsyncStreamPublisher(self)
    }
}

public extension AsyncThrowingStream where Element: Sendable, Failure == Error {
    /// Returns a publisher that emits elements from this AsyncThrowingStream
    var publisher: AsyncStreamPublisher<Element, Error> {
        AsyncStreamPublisher(self)
    }
}
