# CombineAsyncAwait

[![Swift Version](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift Tests](https://github.com/inekipelov/combine-async-await/actions/workflows/swift.yml/badge.svg)](https://github.com/inekipelov/combine-async-await/actions/workflows/swift.yml)  
[![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://developer.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-10.15+-white.svg)](https://developer.apple.com/macos/)
[![tvOS](https://img.shields.io/badge/tvOS-13.0+-black.svg)](https://developer.apple.com/tvos/)
[![watchOS](https://img.shields.io/badge/watchOS-6.0+-orange.svg)](https://developer.apple.com/watchos/)

A lightweight Swift library providing async/await bridge for Combine publishers.

## Usage

### Basic Async Conversion

```swift
import Combine
import CombineAsyncAwait

let publisher = Just(5)
Task {
    let value = await publisher.async()
    print(value) // 5
}
```

### Error Handling

```swift
let errorPublisher = Fail<Int, Error>(error: NSError(domain: "example", code: 1))
Task {
    do {
        let value = try await errorPublisher.async()
        print(value)
    } catch {
        print("Caught error: \(error)")
    }
}
```

### AsyncSequence to Publisher

```swift
import Combine
import CombineAsyncAwait

struct NumberGenerator: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = Int
    var current = 0
    let max: Int
    
    mutating func next() async -> Int? {
        guard current < max else { return nil }
        defer { current += 1 }
        try? await Task.sleep(nanoseconds: 100_000_000)
        return current
    }
    
    func makeAsyncIterator() -> Self { self }
}

let numberSequence = NumberGenerator(max: 5)
let cancellable = numberSequence.publisher
    .map { $0 * 2 }
    .sink(
        receiveCompletion: { print("Completed with: \($0)") },
        receiveValue: { print("Received: \($0)") }
    )
```

### AsyncStream to Publisher

```swift
import Combine
import CombineAsyncAwait

let countdownStream = AsyncStream<Int> { continuation in
    Task {
        for i in (0...5).reversed() {
            continuation.yield(i)
            try? await Task.sleep(for: .seconds(1))
        }
        continuation.finish()
    }
}

let cancellable = countdownStream.publisher.sink { value in
    print("Countdown: \(value)")
}
```

### AsyncThrowingStream to Publisher

```swift
import Combine
import CombineAsyncAwait

enum LoadError: Error {
    case networkError
}

let itemsStream = AsyncThrowingStream<String, Error> { continuation in
    Task {
        do {
            try await Task.sleep(for: .seconds(1))
            continuation.yield("Item 1")
            
            try await Task.sleep(for: .seconds(1))
            continuation.yield("Item 2")
            
            if Bool.random() {
                throw LoadError.networkError
            }
            
            continuation.yield("Item 3")
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }
}

let cancellable = itemsStream.publisher.sink(
    receiveCompletion: { completion in
        switch completion {
        case .finished: print("Loading completed")
        case .failure(let error): print("Loading error: \(error)")
        }
    },
    receiveValue: { print("Received: \($0)") }
)
```

### Task-Based Subscription

```swift
import Combine
import CombineAsyncAwait

let publisher = [1, 2, 3].publisher
var cancellables = Set<AnyCancellable>()

publisher.task { value in
    await someAsyncOperation(value)
} receiveCompletion: { completion in
    switch completion {
    case .finished: await notifyCompletion()
    case .failure(let error): await handleError(error)
    }
}
.store(in: &cancellables)

// With priority
publisher.task(priority: .high) { value in
    await processPriorityData(value)
}
.store(in: &cancellables)
```

### Task to Publisher Conversion

```swift
import Combine
import CombineAsyncAwait

// Convert existing Task to Publisher
let cancellable1 = Task {
    try? await Task.sleep(nanoseconds: 500_000_000)
    return "Task completed!"
}.publisher
.sink(receiveValue: { print("Result: \($0)") })

// Throwing Task
let cancellable2 = Task {
    try await someAsyncOperation()
    return "Success!"
}.sink(
    receiveCompletion: { completion in
        switch completion {
        case .finished: print("Completed")
        case .failure(let error): print("Error: \(error)")
        }
    },
    receiveValue: { print("Result: \($0)") }
)

// Create and convert in one step
let cancellable3 = Task.publisher {
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    return "Hello from Task!"
}.sink { print("Received: \($0)") }

// With error handling
let cancellable4 = Task.publisher {
    if Bool.random() { throw MyError.someError }
    return 42
}.sink(
    receiveCompletion: { completion in
        switch completion {
        case .finished: print("Success")
        case .failure(let error): print("Error: \(error)")
        }
    },
    receiveValue: { print("Value: \($0)") }
)
```

## Installation

Add the following dependency to your `Package.swift` file:

```swift
// Use the latest release
.package(url: "https://github.com/inekipelov/combine-async-await.git", from: "0.2.0")

// Or specify a commit hash for stability
.package(url: "https://github.com/inekipelov/combine-async-await.git", .revision("commit-hash"))
```
