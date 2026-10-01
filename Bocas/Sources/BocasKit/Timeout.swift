import Foundation

/// The result of `work`, or of `fallback` once `timeout` passes, whichever
/// comes first. A slow `work` keeps running and its result is dropped, so a
/// hung speech engine or network call can never leave the HUD up.
public func firstResult<T: Sendable>(within timeout: Duration,
                                     _ work: @escaping @Sendable () async -> T,
                                     orElse fallback: @escaping @Sendable () async -> T) async -> T {
    let (results, result) = AsyncStream.makeStream(of: T.self)
    Task { result.yield(await work()) }
    let timer = Task {
        try await Task.sleep(for: timeout)
        result.yield(await fallback())
    }
    for await value in results {
        timer.cancel()
        return value
    }
    return await fallback()
}
