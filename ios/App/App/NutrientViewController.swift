import Capacitor
import AVFoundation
import Speech

class NutrientViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(NutrientSpeechPlugin())
    }
}

@objc(NutrientSpeechPlugin)
public class NutrientSpeechPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NutrientSpeechPlugin"
    public let jsName = "NutrientSpeech"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "available", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestPermissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise)
    ]
    private let audioEngine = AVAudioEngine()
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?
    private var tapped = false
    private var generation = UUID()

    @objc func available(_ call: CAPPluginCall) {
        call.resolve(["available": SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.isAvailable ?? false])
    }

    @objc override public func requestPermissions(_ call: CAPPluginCall) {
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                call.resolve(["speechRecognition": status == .authorized && granted ? "granted" : "denied"])
            }
        }
    }

    @objc func start(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard SFSpeechRecognizer.authorizationStatus() == .authorized,
                  AVAudioSession.sharedInstance().recordPermission == .granted,
                  let recognizer = SFSpeechRecognizer(locale: Locale(identifier: call.getString("language") ?? "en-US")),
                  recognizer.isAvailable else {
                call.reject("Speech recognition permission is required or recognition is unavailable.")
                return
            }
            self.stopRecording()
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement, options: [])
                try session.setActive(true)
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                self.speechRequest = request
                let input = self.audioEngine.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else {
                    self.stopRecording()
                    call.reject("A microphone is not available on this device.")
                    return
                }
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
                self.tapped = true
                self.audioEngine.prepare()
                try self.audioEngine.start()
                let generation = self.generation
                self.speechTask = recognizer.recognitionTask(with: request) { result, error in
                    guard self.generation == generation else { return }
                    if let result = result {
                        self.notifyListeners("partialResults", data: ["matches": [result.bestTranscription.formattedString]])
                    }
                    if error != nil || result?.isFinal == true {
                        DispatchQueue.main.async { self.stopRecording() }
                    }
                }
                self.notifyListeners("listeningState", data: ["status": "started"])
                call.resolve()
            } catch {
                self.stopRecording()
                call.reject("Unable to start dictation: \(error.localizedDescription)")
            }
        }
    }

    @objc func stop(_ call: CAPPluginCall) {
        DispatchQueue.main.async { self.stopRecording(); call.resolve() }
    }

    private func stopRecording() {
        let wasActive = audioEngine.isRunning || speechTask != nil || tapped
        generation = UUID()
        audioEngine.stop()
        if tapped { audioEngine.inputNode.removeTap(onBus: 0); tapped = false }
        speechRequest?.endAudio()
        let task = speechTask
        speechTask = nil
        speechRequest = nil
        task?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if wasActive { notifyListeners("listeningState", data: ["status": "stopped"]) }
    }
}
