// TaskPublisherTests.swift
// Tests for Task to Publisher conversion

import XCTest
import Combine
@testable import CombineAsyncAwait

final class TaskPublisherTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    func testTaskToPublisher() async throws {
        let task = Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return 42
        }
        
        let expectation = XCTestExpectation(description: "Task publisher emits value")
        
        task.publisher
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }, receiveValue: { value in
                XCTAssertEqual(value, 42)
            })
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testTaskCreationPublisher() async throws {
        let expectation = XCTestExpectation(description: "Task creation publisher emits value")
        
        Task.publisher {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return 123
        }
        .sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                break
            }
            expectation.fulfill()
        }, receiveValue: { value in
            XCTAssertEqual(value, 123)
        })
        .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
