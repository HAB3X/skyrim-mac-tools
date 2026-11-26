import Foundation

public struct ScriptResult: Sendable {
    public let status: Int32
    public let output: String
}

/// Runs a launch script (or another program) and returns its exit status and output (stdout and stderr together).
///
/// The result comes when the script itself exits, not when its output closes: skyrim-together.sh leaves the game and
/// its bring-to-front helper running with the same output, which would otherwise hold the answer until the game quits.
public enum ScriptRunner {
    public static func run(_ executable: URL, arguments: [String] = [], extraEnvironment: [String: String] = [:]) async throws -> ScriptResult {
        let process = Process()
        process.executableURL = executable   // the scripts are executable; their #! line picks bash or zsh
        process.arguments = arguments
        process.currentDirectoryURL = executable.deletingLastPathComponent()
        process.environment = ProcessInfo.processInfo.environment.merging(extraEnvironment) { $1 }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let buffer = OutputBuffer()
        let reader = pipe.fileHandleForReading
        reader.readabilityHandler = { buffer.append($0.availableData) }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                reader.readabilityHandler = nil
                buffer.append(readWithoutWaiting(reader.fileDescriptor))   // what came in after the last callback
                continuation.resume(returning: ScriptResult(status: finished.terminationStatus, output: buffer.text))
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                reader.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    /// Everything already in the pipe, without blocking on writers (the game) that keep it open.
    private static func readWithoutWaiting(_ descriptor: Int32) -> Data {
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        var data = Data()
        var chunk = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = read(descriptor, &chunk, chunk.count)
            guard count > 0 else { break }
            data.append(chunk, count: count)
        }
        return data
    }
}

/// Output gathered from the pipe's callback thread and read once the script exits.
private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ more: Data) {
        lock.withLock { data.append(more) }
    }

    var text: String {
        lock.withLock { String(decoding: data, as: UTF8.self) }
    }
}
