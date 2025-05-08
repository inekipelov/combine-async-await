# CombineAsyncAwait

A lightweight Swift library providing async/await bridge for Combine publishers.

## Features

- Convert Combine publishers to async/await compatible functions
- Handle task cancellation properly
- Support for task-based asynchronous subscription
- Specialized handling for publishers that never fail

## Requirements

- Swift 5.5+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
// Use the latest release
.package(url: "https://github.com/inekipelov/combine-async-await.git", from: "0.1.0")

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
    await publisher.async()
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

### Task-Based Subscription

```swift
// Using task-style sink for asynchronous handlers
let publisher = [1, 2, 3].publisher

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

// Specify task priority
publisher.task(priority: .high) { value in
    await processPriorityData(value)
}
```

## License

MIT License - See LICENSE file for details
