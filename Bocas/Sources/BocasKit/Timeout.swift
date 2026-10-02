import Foundation

/// The result of `work`, or of `fallback` once `timeout` passes, whichever
/// comes first. A slow `work` is cancelled and its result dropped, so a hung
/// speech engine or network call can never leave the HUD up, and a model call
/// that lost the race stops instead of running on unseen.
public func firstResult<T: Sendable>(within timeout: Duration,
                                     _ work: @escaping @Sendable () async -> T,
                                     orElse fallback: @escaping @Sendable () async -> T) async -> T {
    let (results, result) = AsyncStream.makeStream(of: T.self)
    let worker = Task { result.yield(await work()) }
    let timer = Task {
        try await Task.sleep(for: timeout)
        result.yield(await fallback())
        worker.cancel() // cooperative: URLSession and model calls end early
    }
    for await value in results {
        timer.cancel()
        return value
    }
    return await fallback()
}
