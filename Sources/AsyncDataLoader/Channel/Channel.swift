actor Channel<Success: Sendable, Failure: Error>: Sendable {
    private var state = State<Success, Failure>()
}

extension Channel {
    @discardableResult
    func fulfill(_ value: Success) async -> Bool {
        if await state.result == nil {
            await state.setResult(result: value)

            for waiters in await state.waiters {
                waiters.resume(returning: value)
                print("\(#line): resumed waited checked continuation")
            }

            await state.removeAllWaiters()
            print("\(#line): removed all waited checked continuations")

            return false
        }

        print("exiting fulfill with \(await state.waiters.count) continuations not resumed or removed")

        return true
    }

    @discardableResult
    func fail(_ failure: Failure) async -> Bool {
        if await state.failure == nil {
            await state.setFailure(failure: failure)

            for waiters in await state.waiters {
                waiters.resume(throwing: failure)
                print("\(#line): resumed waited checked continuation")
            }

            await state.removeAllWaiters()
            print("\(#line): removed all waited checked continuations")

            return false
        }

        print("exiting fail with \(await state.waiters.count) continuations not resumed or removed")

        return true
    }

    var value: Success {
        get async throws {
            try await withCheckedThrowingContinuation { continuation in
                print("\(#line): created checked continuation")
                Task {
                    if let result = await state.result {
                        continuation.resume(returning: result)
                        print("\(#line): resumed checked continuation")
                    } else if let failure = await self.state.failure {
                        continuation.resume(throwing: failure)
                        print("\(#line): resumed checked continuation")
                    } else {
                        await state.appendWaiters(waiters: continuation)
                        print("\(#line): appended checked continuation")
                    }
                }
            }
        }
    }
}
