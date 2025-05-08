# CombineAsyncAwait

A lightweight Swift library providing async/await bridge for Combine publishers.

## Features

- Convert Combine publishers to async/await compatible functions
- Handle task cancellation properly
- Support for task-based asynchronous subscription
- Specialized handling for publishers that never fail
- Convert AsyncSequence to Combine Publishers with proper backpressure handling

## Requirements

- Swift 5.5+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
// Use the latest release
.package(url: "https://github.com/inekipelov/combine-async-await.git", from: "0.2.0")

// Or specify a commit hash for stability
.package(url: "https://github.com/inekipelov/combine-async-await.git", .revision("commit-hash"))
```

## Usage

### Basic Async Conversion

```swift
import Combine
import CombineAsyncAwait

// Convert a publisher to an async call
// Non-throwing version for publishers that never fail
let publisher = Just(5)
Task {
    let value = await publisher.async()
    print(value) // 5
}

```

### Error Handling

```swift
// Handle errors from publishers
let errorPublisher = Fail<Int, Error>(error: NSError(domain: "example", code: 1))
Task {
    do {
        let value = try await errorPublisher.async()
        print(value)
    } catch {
        print("Caught error: \(error)") // Will print the NSError
    }
}
```

### AsyncSequence to Publisher

```swift
// Convert any AsyncSequence to a Combine Publisher
import Combine
import CombineAsyncAwait

struct NumberGenerator: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = Int
    
    var current = 0
    let max: Int
    
    init(max: Int) {
        self.max = max
    }
    
    mutating func next() async -> Int? {
        guard current < max else { return nil }
        defer { current += 1 }
        // Simulate async work
        try? await Task.sleep(nanoseconds: 100_000_000)
        return current
    }
    
    func makeAsyncIterator() -> Self {
        self
    }
}

// Use the AsyncSequence with Combine
let numberSequence = NumberGenerator(max: 5)
let publisher = numberSequence.publisher

// Now you can use this publisher with standard Combine operators
let cancellable = publisher
    .map { $0 * 2 }
    .sink(
        receiveCompletion: { print("Completed with: \($0)") },
        receiveValue: { print("Received: \($0)") }
    )

// Output:
// Received: 0
// Received: 2
// Received: 4
// Received: 6
// Received: 8
// Completed with: finished
```

### Task-Based Subscription

```swift
// Using task-style sink for asynchronous handlers
let publisher = [1, 2, 3].publisher
let cancellables = Set<AnyCancellable>()

publisher.task { value in
    // This closure can contain async code
    await someAsyncOperation(value)
} receiveCompletion: { completion in
    // Handle completion asynchronously
    switch completion {
    case .finished:
        await notifyCompletion()
    case .failure(let error):
        await handleError(error)
    }
}
.store(in: &cancellables)

// Specify task priority
publisher.task(priority: .high) { value in
    await processPriorityData(value)
}
.store(in: &cancellables)
```

## License

MIT License - See LICENSE file for details
