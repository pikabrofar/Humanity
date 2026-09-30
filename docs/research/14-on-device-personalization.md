# 14 — On-device training and per-user personalization on the Mac

## TL;DR

- **Use a closed-form fit for gaze calibration.** Ridge regression solved with Accelerate/LAPACK (Cholesky) is exact, has no hyperparameters beyond λ, and takes milliseconds for tens to hundreds of calibration points. Gradient training gives no accuracy gain here and adds learning-rate and epoch tuning.
- **Core ML `MLUpdateTask`** can fine-tune only convolution and inner-product (fully connected) layers in the legacy *neuralnetwork* model format, with MSE or cross-entropy loss and SGD or Adam. It is a workable way to personalize the last layer of the optional gaze CNN, but it is legacy tech.
- **The Create ML framework** (`import CreateML`, macOS only) can train `MLHandPoseClassifier` inside a shipping Mac app. That makes user-defined gestures possible, but training takes seconds to minutes and needs dozens of examples per class.
- **MLX Swift** is the most flexible way to do real gradient training on Apple silicon (autodiff, optimizers, unified memory). Use it only if oculOS ever needs to fine-tune more than a head layer.
- **BNNS and MPSGraph** can train too, but they are low-level. Only reach for them if you need to avoid dependencies and have a very specific kernel.

## Key findings

1. **Core ML updatable models.** `MLUpdateTask` (macOS 10.15+) updates neural networks, pipelines, and k-nearest-neighbor classifiers. Only **convolution and inner-product** weights are trainable. Gradients back-propagate through many other layer types. Losses are MSE and categorical cross-entropy. Optimizers are SGD and Adam. You mark models as updatable in coremltools (`NeuralNetworkBuilder.make_updatable`, `set_mean_squared_error_loss`, `set_adam_optimizer`, epochs). *(Uncertain: updatability appears limited to the `neuralnetwork` backend. The default ML Program (`mlprogram`) format from coremltools 7+ does not seem to support it, so convert with `convert_to="neuralnetwork"`.)* An updatable k-NN classifier is a cheap way to add "few-shot" classes over a frozen embedding.
2. **Create ML in-app.** The Create ML framework runs only on macOS for most templates (a subset reached iOS 15+ *(unverified for hand pose)*). `MLHandPoseClassifier` trains from labeled image folders. *(Unverified: it may also accept keypoint data via `DataSource`.)* The parameters cover the algorithm, augmentation, iteration count and batch size. `MLJob`/session APIs from WWDC20 give progress, checkpoints and cancellation. Apple frames the Create ML framework as a developer tool, so expect runs to take minutes, not milliseconds.
3. **MLX Swift** (`ml-explore/mlx-swift`) has `MLXNN` layers, `valueAndGrad`, and `MLXOptimizers` (SGD, Adam, AdamW). The examples include `LinearModelTraining` and `MNISTTrainer` (LeNet, on macOS and iOS), plus LoRA fine-tuning for LLMs. Unified memory means you don't copy data between CPU and GPU. It adds a Swift Package dependency and a Metal shader library.
4. **Accelerate.** LAPACK `dposv` (Cholesky solve) and BLAS `dgemm` run on the CPU's AMX units. An independent benchmark (Cocoa with Love) found BNNS/BNNSGraph competitive for small models on CPU. MPSGraph supports autodiff (`gradients(of:with:)`), but you write the training loop yourself.
5. **Costs** (rough estimates, not measured). Primal ridge costs O(n·d² + d³). Dual/kernel ridge costs O(n²·d + n³). With n ≈ 50–300 calibration points and d ≈ 500–4,000 eye-patch features, the dual form is a 300×300 solve, which takes under 5 ms and under 10 MB. Fine-tuning a CNN head with `MLUpdateTask` for 10–50 epochs on 300 samples should take a few seconds. Training `MLHandPoseClassifier` should take tens of seconds to minutes.

## How to program it (not compiled)

Dual ridge regression with Accelerate, for n calibration samples, d features and 2 outputs:

```swift
import Accelerate
// X: n×d row-major, Y: n×2. Solve (XXᵀ + λI) A = Y, then predict y = xᵀXᵀA.
func fitDualRidge(X: [Double], Y: [Double], n: Int, d: Int, lambda: Double) -> [Double]? {
    var K = [Double](repeating: 0, count: n*n)
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasTrans, Int32(n), Int32(n), Int32(d),
                1, X, Int32(d), X, Int32(d), 0, &K, Int32(n))
    for i in 0..<n { K[i*n+i] += lambda }
    // LAPACK is column-major; K is symmetric. Y must be column-major n×2.
    var A = stride(from: 0, to: 2, by: 1).flatMap { c in (0..<n).map { Y[$0*2+c] } }
    var uplo = Int8(UInt8(ascii: "U")), nn = __CLPK_integer(n), nrhs: __CLPK_integer = 2
    var lda = nn, ldb = nn, info: __CLPK_integer = 0
    dposv_(&uplo, &nn, &nrhs, &K, &lda, &A, &ldb, &info)
    return info == 0 ? A : nil          // weights W = Xᵀ A (d×2)
}
```

Fine-tuning the updatable CNN head:

```swift
let task = try MLUpdateTask(forModelAt: compiledURL, trainingData: batchProvider,
    configuration: cfg, progressHandlers: MLUpdateProgressHandlers(
        forEvents: [.epochEnd], progressHandler: { ctx in print(ctx.metrics[.lossValue] ?? 0) },
        completionHandler: { ctx in try? ctx.model.write(to: userModelURL) }))
task.resume()
```

## Recommendations for oculOS

- **VisionGaze:** keep ridge on eye patches as the main personalization step. Pick λ by leave-one-out CV, which is closed-form for ridge (hat-matrix trick). Refit on every calibration and on drift events. This is the "closed-form wins" case: few samples, a linear model, and the need for instant, reproducible results.
- **Optional gaze CNN:** freeze the backbone. Either (a) run ridge on the CNN's penultimate embedding, which is recommended because it needs no updatable model, or (b) use `MLUpdateTask` on the final inner-product layer only if (a) underfits.
- **Hand-gesture app:** use rules for the core gestures (see report 07). For user-defined gestures, use k-NN or ridge/logistic regression over normalized Vision hand joints (42–63 dims), which trains instantly. Offer `MLHandPoseClassifier` as an optional "train a custom gesture" flow in the background.
- **MLX:** don't adopt it now. Revisit it if you need end-to-end fine-tuning.

## Pitfalls

- Gradient training on under 100 samples overfits and depends on the random seed. Ridge doesn't.
- Normal equations in Float32 lose precision. Standardize features, use Double, and add λ.
- Updatable-model support is tied to the legacy format, and some coremltools versions break `make_updatable` *(verify)*.
- Create ML isn't available in sandboxed iOS-style contexts, and its training time varies by machine. Run it off the main thread and allow cancellation.
- Store per-user weights and models in Application Support, versioned by feature pipeline, because stale weights break silently when preprocessing changes.

## Sources

- https://apple.github.io/coremltools/docs-guides/source/updatable-model-examples.html
- https://machinethink.net/blog/coreml-training-part3/ and https://machinethink.net/blog/coreml-training-part4/
- https://github.com/apple/coremltools/releases/tag/v3.0-beta
- https://developer.apple.com/documentation/createml/mlhandposeclassifier
- https://developer.apple.com/videos/play/wwdc2020/10156/ (Control training in Create ML with Swift)
- https://developer.apple.com/videos/play/wwdc2021/10039/ (Classify hand poses and actions)
- https://github.com/ml-explore/mlx-swift and https://github.com/ml-explore/mlx-swift-examples
- https://www.swift.org/blog/mlx-swift/
- https://www.cocoawithlove.com/blog/macos-ml-frameworks.html
