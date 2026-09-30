# 27 — Voice + gaze multimodal control

## TL;DR

- **Gaze points, sound commits.** Talon Voice is the model to copy: eye tracking (with a "zoom mouse" mode) chooses the target, and non-speech noises (a "pop" or a hiss) click, drag or scroll. Speech handles commands that have names.
- **Noises beat words for clicking.** A pop recognizer can fire within about 100–200 ms of the sound starting *(unverified; Talon publishes no figures)*. A spoken word has to be finished and then decoded. Pinch sits in between.
- **Use the gaze sample from the utterance onset, not the end.** Kaur et al. (2003) found that the fixation on the target comes on average about 630 ms *before* the command word starts. Picking the fixation closest to word onset gave about 95% accuracy.
- **On-device stack:** `SoundAnalysis` plus a Create ML sound classifier for tongue clicks and pops. For words, `SpeechAnalyzer`/`SpeechTranscriber` on macOS 26, with `SFSpeechRecognizer` (`requiresOnDeviceRecognition = true`) as the fallback on macOS 14–15.

## Key findings

- **Talon** combines three inputs: speech, eye/head-tracking mouse, and noise recognition. Built in, `noise(pop)` does a left click or ends a drag or scroll, and `noise(hiss)` does continuous actions. There is also a `dental_click` noise. The "zoom mouse" is eye-only: the first pop zooms in on the gaze region and a second pop clicks inside the magnified view. That is the same idea as the coarse-gaze/fine-commit cascade in report 09. More custom noises can be trained with parrot.py. Noise throttles are set per noise, for example 0.1–0.2 s, so that one sound doesn't fire twice.
- **Look and say:** Kaur et al., ICMI 2003 ("Where is 'it'?") is the key timing result: the eyes land on the target before speech starts. Later work (Chai et al., MSU) found that gaze just before and during a referring word best predicts what the user means. A 2025–26 ACM scoping review covers gaze plus speech in HCI. I did not read it in full.
- **SpeechAnalyzer (WWDC25, macOS 26):** a new on-device model reached through `SpeechTranscriber` modules. It gives volatile (fast, partial) and final results with audio time ranges, runs on-device only, and third-party benchmarks put it at about 40–55× real time for files. Its live latency for short commands is not published *(unverified)*. One report says `SFSpeechRecognizer` can fail silently on macOS 26 *(single GitHub PR; unverified)*. Treat it as legacy.
- **SoundAnalysis:** `SNClassifySoundRequest(mlModel:)` runs a Create ML sound classifier on an `SNAudioStreamAnalyzer`. `windowDuration` and `overlapFactor` control latency. The built-in classifier needs windows of at least 0.5 s. Custom models state their own limits through `windowDurationConstraint`. A small model on short windows (about 0.2–0.3 s) with high overlap is what makes pops feel quick *(the exact minimum for Create ML models is unverified)*.
- **Voice Control (macOS)** already offers "click <name>" and number overlays. It can't be scripted from third-party apps, but oculOS can run alongside it.

## How to program it

```swift
import AVFoundation, SoundAnalysis, CoreML

final class PopClicker: NSObject, SNResultsObserving {
    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer!
    private var streamStartHost: UInt64 = 0          // mach time of frame 0
    private var sampleRate: Double = 48_000
    private var lastFire = Date.distantPast
    let gazeHistory: GazeHistory                     // ring buffer: (hostTime, CGPoint)

    init(gazeHistory: GazeHistory) { self.gazeHistory = gazeHistory }

    func start() throws {
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0); sampleRate = fmt.sampleRate
        analyzer = SNAudioStreamAnalyzer(format: fmt)
        let model = try PopClassifier(configuration: .init()).model   // Create ML .mlmodel
        let req = try SNClassifySoundRequest(mlModel: model)
        req.windowDuration = CMTime(seconds: 0.25, preferredTimescale: 48_000) // check windowDurationConstraint
        req.overlapFactor = 0.75
        try analyzer.add(req, withObserver: self)
        var framePos: AVAudioFramePosition = 0
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, when in
            guard let self else { return }
            if framePos == 0 { self.streamStartHost = when.hostTime }
            self.analyzer.analyze(buf, atAudioFramePosition: framePos)
            framePos += AVAudioFramePosition(buf.frameLength)
        }
        try engine.start()
    }

    func request(_ r: SNRequest, didProduce result: SNResult) {
        guard let c = result as? SNClassificationResult,
              let pop = c.classification(forIdentifier: "pop"), pop.confidence > 0.85,
              Date().timeIntervalSince(lastFire) > 0.25 else { return }   // throttle
        lastFire = Date()
        // Sound onset ≈ window start; look up gaze there, minus a small lead.
        let onsetSec = c.timeRange.start.seconds
        let onsetHost = streamStartHost + secondsToMach(onsetSec) - secondsToMach(0.08)
        guard let p = gazeHistory.fixation(near: onsetHost) else { return }
        DispatchQueue.main.async { postClick(at: p) }  // CGEvent, see report 08
    }
}
```

For words, stream the same mic buffers into a `SpeechAnalyzer` with a `SpeechTranscriber`. Match volatile results against a small command grammar ("click", "scroll down", "right click"). Take the gaze point from the *start* of the audio time range of the matched word, not from the moment the result arrives.

## Recommendations for oculOS

1. Add an optional **VoiceClick** module. Ship a pretrained Create ML "pop / tongue-click / background" classifier, plus a 30-second per-user enrollment that records about 20 examples of each sound and fine-tunes it.
2. Share one **timestamped gaze ring buffer** (report 09) between pinch, pop and speech. Each modality sends only an onset host time and gets the point back.
3. Use the Talon **zoom-mouse** pattern when gaze confidence is low: pop once to magnify, gaze plus pop again to click.
4. Speech should only take commands: keep the grammar small and put words behind `#available(macOS 26, *)`. Don't do dictation.
5. Add a push-to-talk or "sleep"/"wake" mode, so the app avoids Midas touch while the user is talking to people.

## Pitfalls

- **False positives:** keyboard clicks, lip smacks, and speech plosives ("p", "t") sound like pops. Add a speech-activity gate and a keyboard-activity suppress window.
- **Mic permission:** apps need `NSMicrophoneUsageDescription`, and `NSSpeechRecognitionUsageDescription` for `SFSpeechRecognizer`. Both are further TCC prompts.
- **Gaze leaves early:** users look away as they speak or pop, so don't sample gaze when the result arrives.
- **AirPods and Bluetooth mics** add 100–200 ms or more of input latency and switch the audio to a low-rate codec *(unverified figures)*, which hurts the classifier.
- `SFSpeechRecognizer` rate limits and server fallback mean `requiresOnDeviceRecognition` must be set, and `supportsOnDeviceRecognition` must be checked first.

## Sources

- https://talonvoice.com/docs/index.html
- https://talonvoice.com/dl/latest/changelog.html
- https://medium.com/hubabl/make-your-mac-hands-free-part-1-fe70980f36b
- https://handsfreecoding.org/2021/12/12/talon-in-depth-review/
- https://github.com/chaosparrot/parrot.py/blob/master/docs/TALON_VOICE.md
- https://github.com/dwiel/talon_community/wiki/Eye-Tracker (via github-wiki-see.page)
- https://developer.apple.com/videos/play/wwdc2025/277/
- https://www.argmaxinc.com/blog/apple-and-argmax
- https://github.com/djacobs/transcribe-audio/pull/1
- https://developer.apple.com/videos/play/wwdc2021/10036/
- https://www.createwithswift.com/identify-individual-sounds-in-a-live-audio-buffer/
- https://research.tudelft.nl/en/publications/where-is-it-event-synchronization-in-gaze-speech-input-systems/
- https://cse.msu.edu/~jchai/Papers/NAACL07.pdf
- https://dl.acm.org/doi/10.1145/3772318.3791662
