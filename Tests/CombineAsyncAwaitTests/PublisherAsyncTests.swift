import XCTest
import Combine
@testable import CombineAsyncAwait

final class PublisherAsyncTests: XCTestCase {
    
    // Test that a publisher with a single value succeeds
    func testSingleValuePublisher() async throws {
        // Given: A publisher that emits a single value and completes
        let publisher = Just(5)
        
        // When: We get the value asynchronously
        let value = try await publisher.async()
        
        // Then: The value matches what was published
        XCTAssertEqual(value, 5)
    }
    
    // Test that a publisher with multiple values returns the last value
    func testMultipleValuePublisher() async throws {
        // Given: A publisher that emits multiple values then completes
        let publisher = [1, 2, 3, 4, 5].publisher
        
        // When: Retrieve the first emitted value using the 'first' operator with async extension
        let first = try await publisher.first().async()
        // Then: The first value is as expected
        XCTAssertEqual(first, 1)
        
        // When: Retrieve the last emitted value using the 'last' operator with async extension
        let last = try await publisher.last().async()
        // Then: The last value is as expected
        XCTAssertEqual(last, 5)
        
        // When: Retrieve the overall value from the publisher with our async() method
        let value = try await publisher.async()
        // Then: The async() method should return the last emitted value
        XCTAssertEqual(value, 5)
        
        // Additional verification: The async() result equals the value from the 'last' operator
        XCTAssertEqual(last, value)
    }
    
    // Test that a publisher that completes without values throws the right error
    func testEmptyPublisherThrowsNoValueError() async {
        // Given: A publisher that completes without emitting any values
        let publisher = Empty<Int, Never>()
        
        // When/Then: Attempt to retrieve a value asynchronously and expect an error
        do {
            _ = try await publisher.async()
            XCTFail("Expected to throw, but did not throw")
        } catch is EmptyAsyncError {
            // Then: The expected error is thrown
        } catch {
            XCTFail("Incorrect error type: \(error)")
        }
    }
    
    // Test that a failing publisher passes through the error
    func testFailingPublisher() async {
        // Given: A publisher that fails with a TestError
        struct TestError: Error { }
        let publisher = Fail<Int, TestError>(error: TestError())
        
        // When/Then: Attempt to retrieve a value asynchronously and expect TestError
        do {
            _ = try await publisher.async()
            XCTFail("Expected to throw, but did not throw")
        } catch is TestError {
            // Then: The TestError is correctly propagated
        } catch {
            XCTFail("Incorrect error type: \(error)")
        }
    }
    
    // Test task cancellation behavior
    func testCancellation() async {
        // Given: A publisher that won't complete quickly
        let publisher = PassthroughSubject<Int, Never>()
        
        // When: Start an async task to get a value then cancel the task
        let task = Task {
            try? await publisher.async()
        }
        
        // Allow the task to start
        try? await Task.sleep(nanoseconds: 100_000_000)
        // Cancel the task
        task.cancel()
        
        // Allow cancellation to take effect
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Verify that the task is cancelled
        XCTAssertTrue(task.isCancelled)
    }
    
    // Test that we get a value even if cancellation happens after the value is received
    func testCancellationAfterValue() async throws {
        // Given: A publisher that emits a value immediately
        let publisher = Just(42)
        
        // When: Start an async task to retrieve the value
        let result = try await Task {
            try await publisher.async()
        }.value
        
        // Then: The task returns the expected value despite any late cancellation
        XCTAssertEqual(result, 42)
    }
}
