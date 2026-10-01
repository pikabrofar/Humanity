# On-Device Speech-to-Text and Summarization Engines for Humanity

## Summary

Humanity has three workable on-device ASR paths: Apple's built-in engines (SpeechAnalyzer on macOS 26, SFSpeechRecognizer before that), Whisper ports (WhisperKit, whisper.cpp), and NVIDIA Parakeet converted to Core ML by FluidAudio. On English benchmarks, Parakeet through FluidAudio is the fastest of the accurate options. It also comes with diarization and VAD in one Apache-2.0 Swift package. SpeechAnalyzer is a good zero-download engine on macOS 26 and gives live partial results. For summaries, Apple Foundation Models costs nothing to ship, but its 4,096-token context means long meetings have to be summarized in chunks. MLX LLMs are the alternative for macOS 14–15 and long contexts, but they are hard to build with Command Line Tools only.

## Key findings

**Apple SpeechAnalyzer / SpeechTranscriber (macOS 26+)**
- Independent LibriSpeech test on an M2 Pro: 2.12% WER on clean audio and 4.56% on noisy audio. Whisper Small scored 3.74% / 7.95%, Whisper Base 5.42%, Whisper Tiny 7.88%, and legacy on-device SFSpeechRecognizer 9.02%. SpeechAnalyzer ran about 3x faster than Whisper Small. All engines in the test ran 12–40x real time.
- Argmax's earnings-call test (earnings22) is less favorable: SpeechTranscriber 14.0% WER at 70x, WhisperKit base.en 15.2% at 111x, small.en 12.8% at 35x. Apple's engine is competitive, not dominant, on harder real-world audio.
- `volatileResults` gives fast partial text and `isFinal` marks committed text, so it streams natively. Models download through `AssetInventory`, are shared across apps, and add nothing to Humanity's size. SpeechTranscriber covers 21 locales. DictationTranscriber covers 33 and is the fallback. Neither has custom vocabulary or diarization.

**FluidAudio + Parakeet (Apache 2.0 SDK; the models are CC-BY-4.0 NVIDIA weights)**
- Parakeet TDT v3 (0.6B, 25 European languages): 2.6% WER on LibriSpeech clean at about 110x RTFx on an M4 Pro, so one minute of audio takes about 0.5 s. "Parakeet Unified" English: 2.15% WER at 123x (batch) and 2.21% at 29x (streaming).
- Streaming options: Parakeet EOU 120M gets 4.88% WER with 320 ms chunks. Nemotron Streaming 0.6B gets 2.46% at 93.6x.
- Diarization: offline pyannote community-1 reaches **10.6% DER** on AMI SDM at 323x. Streaming options are LS-EEND (20.7% DER) and Sortformer (31.7%). Silero VAD is included.
- Install with SwiftPM (`FluidAudio.git`, `from: "0.12.4"`). Models download from Hugging Face on first use, and the registry and proxy are configurable. More than 40 shipping Mac apps use it (VoiceInk, Spokenly, Hex, and others). Some variants need macOS 15+, so check the package's minimum deployment target against Humanity's macOS 14 floor.

**WhisperKit (Argmax, MIT)** is pure Swift and Core ML, covers about 100 languages, and supports streaming, word timestamps, and VAD. Diarization and custom vocabulary are only in the paid Pro SDK. Whisper large-v3-turbo has 809M parameters, about 1.6 GB at fp16. Choose it when you need language coverage, not top accuracy per unit of speed.

**whisper.cpp (MIT)** uses C/C++ with Metal and optional Core ML encoders. It works well but adds C interop and needs model conversion. It has no advantage over WhisperKit in a Swift app.

**Apple Foundation Models (macOS 26+)** is a model of about 3B parameters with a **fixed 4,096-token context** shared by instructions, tool schemas, the transcript, and the output. Version 26.4 adds `contextSize` and `tokenCount(for:)`. Going over the limit throws `.exceededContextWindowSize`. 4,096 tokens is roughly 20 minutes of speech minus the prompt, so 1-hour meetings need map-reduce chunking. The model is good at extraction and condensing and weak at multi-step reasoning. Guided generation (`@Generable`) gives typed output for action items.

**MLX Swift LLMs (`mlx-swift-lm`, MIT)** run Qwen3-4B 4-bit (about 2.3 GB, Apache 2.0, 32K+ context) at roughly 50–150 tok/s on M-series chips. This covers macOS 14–15 and summarizing a whole meeting in one pass. **Build risk:** MLX's Metal kernels have to be compiled with the `metal` toolchain, which ships with Xcode and not with Command Line Tools. Plain `swift build` cannot build the shaders.

## Recommendations (ranked)

1. **Default ASR: FluidAudio Parakeet.** Use TDT v2 for English and v3 for multilingual. Run it in batch on finished recordings and meeting segments, and use Parakeet EOU or Nemotron streaming for live dictation. It is the best accuracy per unit of speed available, it runs on all supported macOS versions (confirm the minimum target), and it has an Apache-2.0 SDK. Download models on first launch and attribute the CC-BY-4.0 weights in the About and NOTICE files.
2. **Diarization: FluidAudio pyannote community-1 offline** after each meeting (10.6% DER). Use LS-EEND only if you need live speaker labels. Use the same package to avoid a second dependency.
3. **macOS 26 gated: SpeechAnalyzer/SpeechTranscriber** as a "no download" engine and a low-latency live-caption option with volatile results. Fall back to DictationTranscriber for its extra locales. On macOS 14–15, keep **SFSpeechRecognizer with `requiresOnDeviceRecognition`** only as an emergency fallback (9% WER).
4. **Summaries on macOS 26: Foundation Models with map-reduce.** Chunk the transcript into blocks of about 2,500 tokens, using `tokenCount(for:)` to measure them. Extract `@Generable` notes and action items from each chunk, then merge. Start a new session for each chunk.
5. **Optional "Pro summaries" engine: MLX Qwen3-4B-Instruct 4-bit**, for macOS 14–15 users and single-pass summaries of long meetings. Ship it as a separate target or plugin built with `xcodebuild`, or download a prebuilt `mlx.metallib`, so the core app still builds with CLT only.
6. **Skip whisper.cpp.** Add WhisperKit later only if users need languages outside Parakeet v3's 25 European languages and Apple's locales.

## Sources

- https://gigazine.net/gsc_news/en/20260714-apple-speech-analyzer-benchmark/
- https://get-inscribe.com/blog/apple-speech-api-benchmark.html
- https://www.argmaxinc.com/blog/apple-and-argmax
- https://developer.apple.com/videos/play/wwdc2025/277/
- https://dev.to/simple_memo/ios-26s-speechanalyzer-on-a-live-mic-the-5-things-the-docs-dont-tell-you-2ng5
- https://github.com/FluidInference/FluidAudio
- https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md
- https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml
- https://infoq.com/news/2026/03/apple-foundation-models-context
- https://drobinin.com/consulting/foundation-models-apple-intelligence/putting-apple-foundation-models-in-a-real-app/
- https://developer.apple.com/forums/thread/790736
- https://github.com/ml-explore/mlx-swift-lm
- https://github.com/ggml-org/whisper.cpp
