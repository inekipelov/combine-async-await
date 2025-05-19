// AsyncSequencePublisherTests.swift
// Tests for the AsyncSequencePublisher implementation

import XCTest
import Combine
@testable import CombineAsyncAwait

final class AsyncSequencePublisherTests: XCTestCase {
    
    // MARK: - Helper Types
    
    // Simple AsyncSequence implementation for testing
    struct IntegerAsyncSequence: AsyncSequence {
        typealias Element = Int
        
        let values: [Int]
        let delay: TimeInterval?
        let error: Error?
        
        init(values: [Int], delay: TimeInterval? = nil, error: Error? = nil) {
            self.values = values
            self.delay = delay
            self.error = error
        }
        
        func makeAsyncIterator() -> AsyncIterator {
            return AsyncIterator(values: values, delay: delay, error: error)
        }
        
        struct AsyncIterator: AsyncIteratorProtocol {
            let values: [Int]
            let delay: TimeInterval?
            let error: Error?
            var index = 0
            
            mutating func next() async throws -> Int? {
                if let error = error, index == values.count - 1 {
                    throw error
                }
                
                if index < values.count {
                    if let delay = delay {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    defer { index += 1 }
                    return values[index]
                }
                
                return nil
            }
        }
    }
    
    // Custom error for testing
    struct TestError: Error, Equatable { 
        let id: Int
        
        init(_ id: Int = 1) {
            self.id = id
        }
    }
    
    // MARK: - Tests
    
    // Test that an AsyncSequence with a single value is properly published
    func testSingleValueSequence() {
        // Given: An AsyncSequence with a single value
        let sequence = IntegerAsyncSequence(values: [42])
        let publisher = sequence.publisher
        
        // When: We subscribe to the publisher
        let expectation = XCTestExpectation(description: "Receive value from publisher")
        var receivedValue: Int?
        var completed = false
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    completed = true
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                receivedValue = value
            }
        )
        
        // Then: We should receive the correct value and completion
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, 42)
        XCTAssertTrue(completed)
        cancellable.cancel()
    }
    
    // Test that an AsyncSequence with multiple values publishes them all
    func testMultipleValuesSequence() {
        // Given: An AsyncSequence with multiple values
        let sequence = IntegerAsyncSequence(values: [1, 2, 3, 4, 5])
        let publisher = sequence.publisher
        
        // When: We subscribe to the publisher
        let expectation = XCTestExpectation(description: "Receive all values")
        var receivedValues = [Int]()
        var completed = false
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    completed = true
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                receivedValues.append(value)
            }
        )
        
        // Then: We should receive all values in order and completion
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [1, 2, 3, 4, 5])
        XCTAssertTrue(completed)
        cancellable.cancel()
    }
    
    // Test that an AsyncSequence with an error propagates the error
    func testErrorPropagation() {
        // Given: An AsyncSequence that throws an error
        let error = TestError(42)
        let sequence = IntegerAsyncSequence(values: [1, 2, 3], error: error)
        let publisher = sequence.publisher
        
        // When: We subscribe to the publisher
        let expectation = XCTestExpectation(description: "Receive error")
        var receivedValues = [Int]()
        var receivedError: Error?
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("Expected error completion, but received finished")
                case .failure(let error):
                    receivedError = error
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                receivedValues.append(value)
            }
        )
        
        // Then: We should receive values until the error occurs
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [1, 2])
        XCTAssertEqual(receivedError as? TestError, error)
        cancellable.cancel()
    }
    
    // Test that an AsyncSequence with a delay produces values after the delay
    func testDelayedSequence() {
        // Given: An AsyncSequence with a delay
        let sequence = IntegerAsyncSequence(values: [1, 2, 3], delay: 0.2)
        let publisher = sequence.publisher
        
        // When: We subscribe to the publisher
        let expectation = XCTestExpectation(description: "Receive delayed values")
        var receivedValues = [Int]()
        var completed = false
        let startTime = Date()
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    completed = true
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                receivedValues.append(value)
            }
        )
        
        // Then: We should receive all values and completion after appropriate delay
        wait(for: [expectation], timeout: 1.0)
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertEqual(receivedValues, [1, 2, 3])
        XCTAssertTrue(completed)
        // Should take at least 0.6 seconds for all 3 values with 0.2s delay each
        XCTAssertGreaterThanOrEqual(elapsedTime, 0.6)
        cancellable.cancel()
    }
    
    // Test empty AsyncSequence behavior
    func testEmptySequence() {
        // Given: An empty AsyncSequence
        let sequence = IntegerAsyncSequence(values: [])
        let publisher = sequence.publisher
        
        // When: We subscribe to the publisher
        let expectation = XCTestExpectation(description: "Complete without values")
        var receivedValues = [Int]()
        var completed = false
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    completed = true
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                receivedValues.append(value)
            }
        )
        
        // Then: We should receive completion without any values
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedValues.isEmpty)
        XCTAssertTrue(completed)
        cancellable.cancel()
    }
}
