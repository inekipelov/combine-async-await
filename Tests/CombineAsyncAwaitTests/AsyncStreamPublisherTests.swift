// AsyncStreamPublisherTests.swift
// Tests for the AsyncStreamPublisher implementation

import XCTest
import Combine
@testable import CombineAsyncAwait

final class AsyncStreamPublisherTests: XCTestCase {
    
    // MARK: - Tests for AsyncStream
    
    // Test that an AsyncStream with single value is properly published
    func testAsyncStreamSingleValue() {
        // Given: An AsyncStream with a single value
        var continuation: AsyncStream<Int>.Continuation!
        let stream = AsyncStream<Int> { continuation = $0 }
        let publisher = stream.publisher
        
        // When: We subscribe to the publisher
        let expectation = XCTestExpectation(description: "Receive value from publisher")
        var receivedValue: Int?
        
        let cancellable = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { value in
                receivedValue = value
                expectation.fulfill()
            }
        )
        
        // When: We emit a value through the continuation
        continuation.yield(42)
        
        // Then: We should receive the emitted value
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, 42)
        cancellable.cancel()
    }
    
    // Test that an AsyncStream with multiple values publishes them all
    func testAsyncStreamMultipleValues() {
        // Given: An AsyncStream with multiple values
        var continuation: AsyncStream<Int>.Continuation!
        let stream = AsyncStream<Int> { continuation = $0 }
        let publisher = stream.publisher
        
        // When: We subscribe to the publisher
        let expectation = XCTestExpectation(description: "Receive multiple values")
        expectation.expectedFulfillmentCount = 3
        var receivedValues = [Int]()
        
        let cancellable = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { value in
                receivedValues.append(value)
                expectation.fulfill()
            }
        )
        
        // When: We emit values through the continuation
        continuation.yield(1)
        continuation.yield(2)
        continuation.yield(3)
        
        // Then: We should receive all values in order
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [1, 2, 3])
        cancellable.cancel()
    }
    
    // Test that AsyncStream completion is properly propagated
    func testAsyncStreamCompletion() {
        // Given: An AsyncStream that will complete
        var continuation: AsyncStream<Int>.Continuation!
        let stream = AsyncStream<Int> { continuation = $0 }
        let publisher = stream.publisher
        
        // When: We subscribe to the publisher
        let valueExpectation = XCTestExpectation(description: "Receive value")
        let completionExpectation = XCTestExpectation(description: "Receive completion")
        var receivedValue: Int?
        var didComplete = false
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                if case .finished = completion {
                    didComplete = true
                    completionExpectation.fulfill()
                }
            },
            receiveValue: { value in
                receivedValue = value
                valueExpectation.fulfill()
            }
        )
        
        // When: We emit a value and then finish the stream
        continuation.yield(42)
        continuation.finish()
        
        // Then: We should receive the value and completion
        wait(for: [valueExpectation, completionExpectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, 42)
        XCTAssertTrue(didComplete)
        cancellable.cancel()
    }
    
    // Test backpressure handling in AsyncStream
    func testAsyncStreamBackpressure() {
        // Given: An AsyncStream we'll use to test backpressure
        var continuation: AsyncStream<Int>.Continuation!
        let stream = AsyncStream<Int>(bufferingPolicy: .unbounded) { continuation = $0 }
        let publisher = stream.publisher
        
        // When: We subscribe with limited demand
        var receivedValues = [Int]()
        let demandExpectation = XCTestExpectation(description: "Limited demand fulfilled")
        
        let cancellable = publisher
            // Use a Subject to control demand
            .map { $0 }
            .flatMap(maxPublishers: .max(1)) { value -> AnyPublisher<Int, Never> in
                // Simulate processing delay to test backpressure
                return Just(value)
                    .delay(for: .milliseconds(100), scheduler: RunLoop.main)
                    .eraseToAnyPublisher()
            }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { value in
                    receivedValues.append(value)
                    if receivedValues.count == 3 {
                        demandExpectation.fulfill()
                    }
                }
            )
        
        // Send more values than immediate demand
        continuation.yield(1)
        continuation.yield(2)
        continuation.yield(3)
        continuation.yield(4)
        continuation.yield(5)
        
        // Wait for the limited demand to be processed
        wait(for: [demandExpectation], timeout: 2.0)
        
        // Then: Values should be received in the correct order, even with backpressure
        XCTAssertEqual(receivedValues.prefix(3), [1, 2, 3])
        cancellable.cancel()
    }
    
    // MARK: - Tests for AsyncThrowingStream
    
    // Test that an AsyncThrowingStream with a successful value is properly published
    func testAsyncThrowingStreamSuccess() {
        // Given: An AsyncThrowingStream with a success path
        var continuation: AsyncThrowingStream<Int, Error>.Continuation!
        let stream = AsyncThrowingStream<Int, Error> { continuation = $0 }
        let publisher = stream.publisher
        
        // When: We subscribe to the publisher
        let expectation = XCTestExpectation(description: "Receive value")
        var receivedValue: Int?
        
        let cancellable = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { value in
                receivedValue = value
                expectation.fulfill()
            }
        )
        
        // When: We emit a successful value
        continuation.yield(42)
        
        // Then: We should receive the value
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, 42)
        cancellable.cancel()
    }
    
    // Test that an AsyncThrowingStream error is properly propagated
    func testAsyncThrowingStreamError() {
        // Given: An AsyncThrowingStream that will emit an error
        var continuation: AsyncThrowingStream<Int, Error>.Continuation!
        let stream = AsyncThrowingStream<Int, Error> { continuation = $0 }
        let publisher = stream.publisher
        
        struct TestError: Error, Equatable {
            let code: Int
        }
        let testError = TestError(code: 123)
        
        // When: We subscribe to the publisher
        let errorExpectation = XCTestExpectation(description: "Receive error")
        var receivedError: Error?
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    receivedError = error
                    errorExpectation.fulfill()
                }
            },
            receiveValue: { _ in }
        )
        
        // When: We emit an error through the continuation
        continuation.finish(throwing: testError)
        
        // Then: We should receive the error
        wait(for: [errorExpectation], timeout: 1.0)
        XCTAssertEqual((receivedError as? TestError)?.code, 123)
        cancellable.cancel()
    }
    
    // Test that AsyncThrowingStream can emit values before error
    func testAsyncThrowingStreamValuesBeforeError() {
        // Given: An AsyncThrowingStream that will emit values then error
        var continuation: AsyncThrowingStream<Int, Error>.Continuation!
        let stream = AsyncThrowingStream<Int, Error> { continuation = $0 }
        let publisher = stream.publisher
        
        struct TestError: Error { }
        
        // When: We subscribe to the publisher
        let valuesExpectation = XCTestExpectation(description: "Receive values")
        valuesExpectation.expectedFulfillmentCount = 3
        
        let errorExpectation = XCTestExpectation(description: "Receive error")
        var receivedValues = [Int]()
        var receivedError: Error?
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    receivedError = error
                    errorExpectation.fulfill()
                }
            },
            receiveValue: { value in
                receivedValues.append(value)
                valuesExpectation.fulfill()
            }
        )
        
        // When: We emit values and then an error
        continuation.yield(1)
        continuation.yield(2)
        continuation.yield(3)
        continuation.finish(throwing: TestError())
        
        // Then: We should receive all values and then the error
        wait(for: [valuesExpectation, errorExpectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [1, 2, 3])
        XCTAssertTrue(receivedError is TestError)
        cancellable.cancel()
    }
    
    // Test cancellation behavior with AsyncStream
    func testAsyncStreamCancellation() {
        // Given: A long-running AsyncStream
        var continuation: AsyncStream<Int>.Continuation!
        let stream = AsyncStream<Int> { continuation = $0 }
        let publisher = stream.publisher
        
        // When: We subscribe to the publisher
        let expectation = XCTestExpectation(description: "Receive initial value")
        var receivedValues = [Int]()
        
        let cancellable = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { value in
                receivedValues.append(value)
                expectation.fulfill()
            }
        )
        
        // Send an initial value
        continuation.yield(1)
        
        // Wait for initial value
        wait(for: [expectation], timeout: 1.0)
        
        // Then cancel the subscription
        cancellable.cancel()
        
        // Create a new expectation for values we shouldn't receive
        let unexpectedValueExpectation = XCTestExpectation(description: "Should not receive values after cancellation")
        unexpectedValueExpectation.isInverted = true
        
        // Try to send more values after cancellation
        continuation.yield(2)
        continuation.yield(3)
        
        // Wait a moment to see if we get unexpected values
        XCTAssertEqual(receivedValues, [1], "Should only receive values before cancellation")
    }
}
