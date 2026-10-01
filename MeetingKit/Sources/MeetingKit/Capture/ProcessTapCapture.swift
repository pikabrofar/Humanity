import AVFoundation
import CoreAudio

struct CaptureError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

typealias BufferHandler = @Sendable (AVAudioPCMBuffer, _ hostSeconds: Double?) -> Void

/// Records one app's output through a Core Audio process tap: a tap on the app's
/// processes, wrapped in a private aggregate device whose IO callback delivers the
/// audio. Unlike ScreenCaptureKit it needs no Screen Recording permission, only the
/// narrower audio-capture prompt (NSAudioCaptureUsageDescription), and the app keeps
/// playing normally.
@available(macOS 14.4, *)
final class ProcessTapCapture {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    // Not the realtime thread: AAC encoding in the callback is too slow for that.
    private let queue = DispatchQueue(label: "MeetingKit.processTap", qos: .userInitiated)
    private var buffers = 0 // only touched on `queue`

    func start(_ source: AudioSource, onBuffer: @escaping BufferHandler) async throws {
        let description: CATapDescription
        switch source {
        case .app(let app):
            guard !app.processObjects.isEmpty else { throw CaptureError("\(app.name) hasn't played any audio yet.") }
            description = CATapDescription(stereoMixdownOfProcesses: app.processObjects)
        case .allSystemAudio:
            let own = CoreAudioHelpers.processObject(pid: getpid()).map { [$0] } ?? []
            description = CATapDescription(stereoGlobalTapButExcludeProcesses: own)
        }
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .unmuted // the user still has to hear the call
        do {
            try check(AudioHardwareCreateProcessTap(description, &tapID), "create the audio tap")

            var stream = AudioStreamBasicDescription()
            try check(CoreAudioHelpers.read(tapID, kAudioTapPropertyFormat, &stream), "read the tap format")
            guard let format = AVAudioFormat(streamDescription: &stream) else { throw CaptureError("Unsupported tap format.") }

            // The output device clocks the aggregate; drift compensation keeps the tap in step.
            // ponytail: switching output devices mid-call keeps the old clock; the call track can
            // go silent then, which MeetingRecorder reports at stop instead of rebuilding the tap.
            guard let outputUID = CoreAudioHelpers.defaultOutputDeviceUID() else { throw CaptureError("No audio output device.") }
            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "MeetingKit Tap",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true, // not listed for other apps, gone if we crash
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                                   kAudioSubTapUIDKey: description.uuid.uuidString]],
            ]
            try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "create the aggregate device")

            // When the output device also has inputs (AirPods, a USB headset or interface), the
            // aggregate's input list carries those streams first and the tap's last. Wrapping
            // the whole list would record the headset mic, or nothing, as the call.
            let tapBuffers = format.isInterleaved ? 1 : Int(format.channelCount)
            try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, inputTime, _, _ in
                let all = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                guard all.count >= tapBuffers else { return }
                let list = AudioBufferList.allocate(maximumBuffers: tapBuffers)
                defer { free(list.unsafeMutablePointer) }
                for i in 0..<tapBuffers { list[i] = all[all.count - tapBuffers + i] }
                // No-copy view of Core Audio's buffer; only valid during this call, which is
                // fine because the writer encodes it before returning.
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: list.unsafePointer, deallocator: nil) else { return }
                let time = inputTime.pointee
                let host = time.mFlags.contains(.hostTimeValid) ? AVAudioTime.seconds(forHostTime: time.mHostTime) : nil
                self.buffers += 1
                onBuffer(buffer, host)
            }, "install the audio callback")
            guard procID != nil else { throw CaptureError("Couldn't install the audio callback.") }
            try check(AudioDeviceStart(aggregateID, procID), "start the audio tap")
            // Every call above can succeed and still deliver nothing: on first use macOS shows
            // the audio-capture prompt mid-setup and the IO callback is never called. The
            // output device clocks the aggregate, so even silence arrives within milliseconds.
            var waited = 0
            while queue.sync(execute: { buffers == 0 }) {
                guard waited < 60 else {
                    throw CaptureError("The audio tap delivered no sound. If macOS just asked to allow system audio recording, allow it and record again.")
                }
                waited += 1
                try await Task.sleep(nanoseconds: 50_000_000)
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, procID)
            if let procID { AudioDeviceDestroyIOProcID(aggregateID, procID) }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    private func check(_ status: OSStatus, _ action: String) throws {
        if status != noErr { throw CaptureError("Couldn't \(action) (error \(status)).") }
    }
}
