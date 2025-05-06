import XCTest
import Combine
@testable import CombineAsyncAwait

final class PublisherTaskTests: XCTestCase {
    func testTaskBasicFunctionality() async {
        let valueExpectation = expectation(description: "Should receive value")
        let completionExpectation = expectation(description: "Should complete")
        
        let publisher = Just(42)
        
        let cancellable = publisher.task(
            receiveCompletion: { completion in
                if case .finished = completion {
                    completionExpectation.fulfill()
                }
            },
            receiveValue: { value in
                XCTAssertEqual(value, 42)
                valueExpectation.fulfill()
            }
        )
        
        defer { cancellable.cancel() }
        await fulfillment(of: [valueExpectation, completionExpectation], timeout: 1.0)
    }
    
    func testTaskErrorHandling() async {
        let errorExpectation = expectation(description: "Should receive error")
        let customError = NSError(domain: "test", code: 123)
        
        let publisher = Fail<Int, Error>(error: customError)
        
        let cancellable = publisher.task(
            receiveCompletion: { completion in
                if case .failure(let error) = completion, let nsError = error as NSError? {
                    XCTAssertEqual(nsError.code, 123)
                    XCTAssertEqual(nsError.domain, "test")
                    errorExpectation.fulfill()
                }
            },
            receiveValue: { _ in
                XCTFail("Should not receive value")
            }
        )
        
        defer { cancellable.cancel() }
        await fulfillment(of: [errorExpectation], timeout: 1.0)
    }
    
    func testTaskMultipleValues() async {
        let expectation = expectation(description: "Should receive all values")
        expectation.expectedFulfillmentCount = 3
        
        let subject = PassthroughSubject<Int, Never>()
        
        actor Collector {
            private(set) var values = [Int]()
            func append(_ value: Int) {
                values.append(value)
            }
        }
        let collector = Collector()
        
        let cancellable = subject.task { value in
            await collector.append(value)
            expectation.fulfill()
        }
        
        subject.send(1)
        subject.send(2)
        subject.send(3)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        let receivedValues = await collector.values
        XCTAssertEqual(receivedValues, [1, 2, 3])
        cancellable.cancel()
    }
    
    func testTaskCancellation() async {
        let valueExpectation = expectation(description: "Should receive value")
        let subject = PassthroughSubject<Int, Never>()
        
        let cancellable = subject.task { value in
            XCTAssertEqual(value, 42)
            valueExpectation.fulfill()
        }
        
        subject.send(42)
        await fulfillment(of: [valueExpectation], timeout: 1.0)
        
        // Create a new expectation - if the task is properly cancelled,
        // this won't be fulfilled
        let shouldNotBeCalledExpectation = expectation(description: "Should not be called")
        shouldNotBeCalledExpectation.isInverted = true
        
        // Cancel before sending next value
        cancellable.cancel()
        
        _ = subject.task { _ in
            shouldNotBeCalledExpectation.fulfill()
        }
        
        subject.send(100)
        
        await fulfillment(of: [shouldNotBeCalledExpectation], timeout: 0.5)
    }
    
    func testTaskPriority() async {
        let highPriorityExpectation = expectation(description: "High priority task")
        let backgroundPriorityExpectation = expectation(description: "Background priority task")
        
        actor TaskPriorityCollector {
            private(set) var taskPriorities: [TaskPriority] = []
            func append(_ value: TaskPriority) {
                taskPriorities.append(value)
            }
        }
        let collector = TaskPriorityCollector()
        
        // Several heavy publishers executing concurrently
        let highPriorityPublisher = Just(1)
        let bgPriorityPublisher = Just(2)
        
        _ = bgPriorityPublisher.task(priority: .background) { _ in
            // Simulate CPU-intensive work
            for _ in 1...1000 { _ = sqrt(Double.random(in: 1...1000)) }
            
            await collector.append(.background)
            backgroundPriorityExpectation.fulfill()
        }
        
        _ = highPriorityPublisher.task(priority: .high) { _ in
            // Simulate CPU-intensive work
            for _ in 1...1000 { _ = sqrt(Double.random(in: 1...1000)) }
            
            await collector.append(.high)
            highPriorityExpectation.fulfill()
        }
        
        await fulfillment(of: [highPriorityExpectation, backgroundPriorityExpectation], timeout: 3)
        
        // We're only verifying both tasks completed successfully
        let first = await collector.taskPriorities.first
        let last = await collector.taskPriorities.last
        XCTAssertEqual(first, .high, "First task should be high priority")
        XCTAssertEqual(last, .background, "Last task should be background priority")
    }
    
    func testTaskDefaultCompletion() async {
        let valueExpectation = expectation(description: "Should receive value")
        
        let publisher = Just(123)
        
        // Not specifying receiveCompletion parameter, using the default
        let cancellable = publisher.task { value in
            XCTAssertEqual(value, 123)
            valueExpectation.fulfill()
        }
        
        defer { cancellable.cancel() }
        await fulfillment(of: [valueExpectation], timeout: 1.0)
    }
}
