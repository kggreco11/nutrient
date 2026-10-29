import AVFoundation
import Speech
import Vision
import SwiftUI

@MainActor final class NativeDictation: ObservableObject {
  @Published var transcript = ""
  @Published var listening = false
  @Published var error: String?
  private let engine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var tapped = false
  private var generation = UUID()
  func start() async {
    let speech = await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
    }
    let microphone = await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
    }
    guard speech == .authorized, microphone else {
      error = "Allow microphone and speech access in iPhone Settings to dictate."
      return
    }
    stop()
    transcript = ""
    let session = UUID()
    generation = session
    do {
      let audio = AVAudioSession.sharedInstance()
      try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audio.setActive(true)
      guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
        recognizer.isAvailable
      else {
        error = "Dictation is unavailable right now."
        return
      }
      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      self.request = request
      let input = engine.inputNode
      input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) {
        buffer, _ in request.append(buffer)
      }
      tapped = true
      task = recognizer.recognitionTask(with: request) { [weak self] result, error in
        Task { @MainActor in
          guard let self, self.generation == session else { return }
          if let result { self.transcript = result.bestTranscription.formattedString }
          if result?.isFinal == true || error != nil { self.stop() }
        }
      }
      engine.prepare()
      try engine.start()
      listening = true
    } catch {
      self.error = "Couldn't start dictation. Try again."
      stop()
    }
  }
  func stop() {
    generation = UUID()
    engine.stop()
    if tapped {
      engine.inputNode.removeTap(onBus: 0)
      tapped = false
    }
    request?.endAudio()
    task?.cancel()
    task = nil
    request = nil
    listening = false
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
struct NativeScanner: UIViewControllerRepresentable {
  var scanned: (String) -> Void
  var failed: (String) -> Void
  func makeUIViewController(context: Context) -> ScannerController {
    let controller = ScannerController()
    controller.scanned = scanned
    controller.failed = failed
    return controller
  }
  func updateUIViewController(_ controller: ScannerController, context: Context) {}
  static func dismantleUIViewController(_ controller: ScannerController, coordinator: ()) {
    controller.stop()
  }
}
final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
  private let capture = AVCaptureSession()
  private let queue = DispatchQueue(label: "nutrient.camera")
  private var preview: AVCaptureVideoPreviewLayer?
  private var completed = false
  var scanned: ((String) -> Void)?
  var failed: ((String) -> Void)?
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
      guard let self else { return }
      guard granted else {
        DispatchQueue.main.async {
          self.failed?("Allow camera access in iPhone Settings, or enter the barcode.")
        }
        return
      }
      self.queue.async { self.configure() }
    }
  }
  private func configure() {
    guard let device = AVCaptureDevice.default(for: .video),
      let input = try? AVCaptureDeviceInput(device: device), capture.canAddInput(input)
    else {
      DispatchQueue.main.async { self.failed?("Camera is unavailable on this device.") }
      return
    }
    capture.addInput(input)
    let output = AVCaptureMetadataOutput()
    guard capture.canAddOutput(output) else { return }
    capture.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: .main)
    output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]
    DispatchQueue.main.async {
      let layer = AVCaptureVideoPreviewLayer(session: self.capture)
      layer.videoGravity = .resizeAspectFill
      layer.frame = self.view.bounds
      self.view.layer.addSublayer(layer)
      self.preview = layer
    }
    capture.startRunning()
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    preview?.frame = view.bounds
  }
  func stop() { queue.async { if self.capture.isRunning { self.capture.stopRunning() } } }
  func metadataOutput(
    _ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard !completed,
      let code = metadataObjects.compactMap({
        ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue
      }).first
    else { return }
    completed = true
    stop()
    scanned?(code)
  }
}

// Capture stays native. Vision reads the photograph on-device; only recognized
// label text is sent to the same private service used by chat.
struct NativeLabelCamera: UIViewControllerRepresentable {
  var captured: (UIImage) -> Void
  var cancelled: () -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.delegate = context.coordinator
    return picker
  }
  func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
  final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    let parent: NativeLabelCamera
    init(_ parent: NativeLabelCamera) { self.parent = parent }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.cancelled() }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      if let image = info[.originalImage] as? UIImage { parent.captured(image) }
      else { parent.cancelled() }
    }
  }
}

struct NativeLabelDraft: Decodable {
  let name: String
  let serving: String
  let calories: Double?
  let values: [String: Double?]
}
struct NativeLabelResponse: Decodable { let label: NativeLabelDraft }

@MainActor final class NativeLabelReader: ObservableObject {
  @Published var busy = false
  @Published var stage = ""
  @Published var error: String?
  @Published var draft: NativeLabelDraft?
  private(set) var recognizedText = ""
  private var work: Task<Void, Never>?
  func cancel() { work?.cancel(); busy = false }
  func read(_ image: UIImage) {
    work?.cancel()
    busy = true
    error = nil
    stage = "Reading label…"
    // Normalize camera rotation before handing the pixels to Vision.
    let size = image.size
    let scale = min(1, 2400 / max(size.width, size.height))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let normalized = UIGraphicsImageRenderer(size: CGSize(width: size.width * scale, height: size.height * scale), format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: CGSize(width: size.width * scale, height: size.height * scale)))
    }
    guard let data = normalized.jpegData(compressionQuality: 0.9) else {
      busy = false; error = "Couldn’t read this photo. Try another."; return
    }
    work = Task {
      do {
        let text = try await Task.detached(priority: .userInitiated) {
          try Self.recognize(data)
        }.value
        try Task.checkCancellation()
        recognizedText = text
        try await convert(text)
      } catch is CancellationError { }
      catch { self.error = error.localizedDescription }
      if !Task.isCancelled { busy = false }
    }
  }
  func retry() {
    guard !busy, !recognizedText.isEmpty else { return }
    busy = true; error = nil
    work = Task {
      do { try await convert(recognizedText) }
      catch is CancellationError { }
      catch { self.error = error.localizedDescription }
      if !Task.isCancelled { busy = false }
    }
  }
  nonisolated static func recognize(_ data: Data) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    try VNImageRequestHandler(data: data).perform([request])
    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
  }
  private func convert(_ text: String) async throws {
    guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
      throw NSError(domain: "Nutrient", code: 1, userInfo: [NSLocalizedDescriptionKey: "No readable label found. Get closer and photograph the full Nutrition Facts panel."])
    }
    stage = "Filling nutrition facts…"
    let data = try await NativeBackend().request(["text": text], path: "/api/label")
    try Task.checkCancellation()
    draft = try JSONDecoder().decode(NativeLabelResponse.self, from: data).label
  }
}
