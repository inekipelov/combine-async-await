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
        
        // Check that all values were received, but don't enforce order
        // since async tasks may complete in different order
        XCTAssertEqual(Set(receivedValues), Set([1, 2, 3]))
        XCTAssertEqual(receivedValues.count, 3)
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
            private(set) var taskPriorities: [TaskPriority?] = []
            func append(_ value: TaskPriority?) {
                taskPriorities.append(value)
            }
        }
        let collector = TaskPriorityCollector()
        
        // Test that task is created with high priority
        let highPriorityPublisher = Just(1)
        _ = highPriorityPublisher.task(priority: .high) { _ in
            // Verify the current task's priority matches what we set
            await collector.append(Task.currentPriority)
            highPriorityExpectation.fulfill()
        }
        
        // Test that task is created with background priority
        let bgPriorityPublisher = Just(2)
        _ = bgPriorityPublisher.task(priority: .background) { _ in
            // Verify the current task's priority matches what we set
            await collector.append(Task.currentPriority)
            backgroundPriorityExpectation.fulfill()
        }
        
        await fulfillment(of: [highPriorityExpectation, backgroundPriorityExpectation], timeout: 3)
        
        // Get priorities that were actually applied to the tasks
        let priorities = await collector.taskPriorities
        
        // Verify both tasks completed
        XCTAssertEqual(priorities.count, 2, "Both tasks should have completed")
        
        // Verify the correct priorities were applied to tasks
        // Note: We don't assert the order, just that both priorities are present
        XCTAssertTrue(priorities.contains(.high), "A task should have high priority")
        XCTAssertTrue(priorities.contains(.background), "A task should have background priority")
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
