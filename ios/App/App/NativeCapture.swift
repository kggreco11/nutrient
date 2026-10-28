import AVFoundation
import Speech
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
