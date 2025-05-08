import XCTest
import Combine
@testable import CombineAsyncAwait

/*
 * Test files in the project:
 *
 * 1. CombineAsyncAwaitTests.swift - This file, previously contained the main tests,
 *    but now serves as a placeholder after test reorganization
 *
 * 2. PublisherAsyncTests.swift - Contains tests for Publisher+Async extension:
 *    - Tests for single/multiple value publishers using async()
 *    - Error handling tests for failing publishers
 *    - Cancellation behavior tests
 *    - Tests for delayed publishers and infinite publishers
 *
 * 3. PublisherTaskTests.swift - Contains tests for Publisher+Task extension:
 *    - Basic task functionality tests
 *    - Error handling tests for task-based operations
 *    - Tests for publishers emitting multiple values
 *    - Task cancellation tests
 *    - Task priority tests
 */

final class CombineAsyncAwaitTests: XCTestCase {
    // Test file is now empty after moving task-related tests to PublisherTaskTests.swift
}
