// MIT License
//
// Copyright (c) 2026 Otávio C.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import HolodeckTestSupport
import Testing
@testable import HolodeckCore

struct URLHistoryStoreTests {

    private func store(in dir: URL) -> URLHistoryStore {
        URLHistoryStore.live(configResolver: .mock(base: dir))
    }

    @Test("It should return an empty list when the file does not exist")
    func loadOnMissingReturnsEmpty() throws {
        try withTemporaryDirectory { dir in
            // Given
            let store = store(in: dir)

            // Then
            #expect(store.load().isEmpty)
        }
    }

    @Test("It should record entries in most-recent-first order")
    func recordPrependsEntries() throws {
        try withTemporaryDirectory { dir in
            // Given
            let store = store(in: dir)

            // When
            let after = try store.record("https://a")
            let next = try store.record("https://b")

            // Then
            #expect(after == ["https://a"])
            #expect(next == ["https://b", "https://a"])
        }
    }

    @Test("It should move duplicates to the front instead of growing the list")
    func recordDedupesByMovingToFront() throws {
        try withTemporaryDirectory { dir in
            // Given
            let store = store(in: dir)
            _ = try store.record("a")
            _ = try store.record("b")
            _ = try store.record("c")

            // When
            let after = try store.record("a")

            // Then
            #expect(after == ["a", "c", "b"])
        }
    }

    @Test("It should cap the list at the capacity constant")
    func recordCapsAtCapacity() throws {
        try withTemporaryDirectory { dir in
            // Given
            let store = store(in: dir)

            // When (record capacity+5 distinct entries)
            var last: [String] = []
            for index in 0..<(URLHistoryStore.capacity + 5) {
                last = try store.record("url-\(index)")
            }

            // Then
            #expect(last.count == URLHistoryStore.capacity)
            #expect(last.first == "url-\(URLHistoryStore.capacity + 4)")
        }
    }

    @Test("It should persist records across instances")
    func recordPersistsAcrossInstances() throws {
        try withTemporaryDirectory { dir in
            // Given
            let first = store(in: dir)
            _ = try first.record("https://apple.com")

            // When
            let second = store(in: dir)

            // Then
            #expect(second.load() == ["https://apple.com"])
        }
    }

    @Test("It should return an empty list when the file is malformed")
    func loadOnMalformedReturnsEmpty() throws {
        try withTemporaryDirectory { dir in
            // Given
            try Data("not json".utf8).write(to: dir.appendingPathComponent("url-history.json"))
            let store = store(in: dir)

            // Then
            #expect(store.load().isEmpty)
        }
    }
}
