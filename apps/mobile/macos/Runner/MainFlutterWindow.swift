import Cocoa
import FlutterMacOS
import AVFoundation
import Vision
import ImageIO

class MainFlutterWindow: NSWindow {
  private var photoCamera: WeekPlanCamera?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let cameraChannel = FlutterMethodChannel(
      name: "kondate/week_plan_camera",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    cameraChannel.setMethodCallHandler { [weak self] call, result in
      if call.method == "cancel" {
        self?.photoCamera?.cancel()
        result(nil)
        return
      }
      guard call.method == "capture" else { result(FlutterMethodNotImplemented); return }
      guard let self = self, self.photoCamera == nil else {
        result(FlutterError(code: "busy", message: "Die Kamera ist bereits geöffnet.", details: nil))
        return
      }
      let camera = WeekPlanCamera()
      self.photoCamera = camera
      camera.open(parent: self) { [weak self] value in
        self?.photoCamera = nil
        result(value)
      }
    }

    let textChannel = FlutterMethodChannel(name: "kondate/week_plan_text",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    textChannel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else { result(FlutterMethodNotImplemented); return }
      guard let bytes = call.arguments as? FlutterStandardTypedData,
            bytes.data.count <= 4 * 1024 * 1024 else {
        result(FlutterError(code: "invalid_photo", message: "Bitte ein kleineres Foto auswählen.", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          guard let source = CGImageSourceCreateWithData(bytes.data as CFData, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                image.width <= 2000, image.height <= 2000 else {
            throw NSError(domain: "KondatePhoto", code: 1)
          }
          let request = VNRecognizeTextRequest()
          request.recognitionLevel = .accurate
          let supported = try VNRecognizeTextRequest.supportedRecognitionLanguages(
            for: .accurate, revision: request.revision)
          request.recognitionLanguages = ["de-DE", "en-US"].filter { supported.contains($0) }
          request.usesLanguageCorrection = true
          try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
          let lines: [[String: Any]] = (request.results ?? []).prefix(500).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return ["text": candidate.string, "x": box.minX, "y": 1 - box.maxY,
                    "width": box.width, "height": box.height]
          }
          DispatchQueue.main.async { result(lines) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "recognition_failed", message:
              "Text konnte auf diesem Gerät nicht gelesen werden. Bitte ein schärferes Foto wählen oder die Mahlzeiten unten eintragen.", details: nil))
          }
        }
      }
    }

    super.awakeFromNib()
  }
}

/// A native camera sheet is needed because image_picker only provides a file
/// chooser on macOS. No microphone input, file write, or network access here.
private final class WeekPlanCamera: NSObject, AVCapturePhotoCaptureDelegate {
  private let session = AVCaptureSession()
  private let output = AVCapturePhotoOutput()
  private let queue = DispatchQueue(label: "kondate.weekPlanCamera")
  private var panel: NSPanel?
  private weak var parent: NSWindow?
  private var completion: ((Any?) -> Void)?
  private var captureButton: NSButton?

  func open(parent: NSWindow, completion: @escaping (Any?) -> Void) {
    self.parent = parent
    self.completion = completion
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: configure()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
        DispatchQueue.main.async {
          if allowed { self?.configure() } else { self?.denied() }
        }
      }
    default: denied()
    }
  }

  private func denied() {
    finish(FlutterError(code: "camera_denied", message:
      "Bitte Kondate unter Systemeinstellungen → Datenschutz & Sicherheit → Kamera erlauben, oder ein Foto auswählen.", details: nil))
  }

  private func configure() {
    guard completion != nil else { return }
    guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device) else {
      finish(FlutterError(code: "no_camera", message: "Keine Kamera verfügbar. Bitte ein Foto auswählen.", details: nil))
      return
    }
    session.beginConfiguration()
    session.sessionPreset = .photo
    guard session.canAddInput(input), session.canAddOutput(output) else {
      session.commitConfiguration()
      finish(FlutterError(code: "camera_unavailable", message: "Kamera nicht verfügbar. Bitte ein Foto auswählen.", details: nil))
      return
    }
    session.addInput(input)
    session.addOutput(output)
    session.commitConfiguration()

    let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 680, height: 540),
      styleMask: [.titled], backing: .buffered, defer: false)
    panel.title = "Wochenplan fotografieren"
    let content = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 540))
    let preview = NSView(frame: NSRect(x: 16, y: 70, width: 648, height: 454))
    preview.wantsLayer = true
    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.frame = preview.bounds
    layer.videoGravity = .resizeAspect
    preview.layer?.addSublayer(layer)
    content.addSubview(preview)
    let cancel = NSButton(title: "Abbrechen", target: self, action: #selector(cancelPhoto))
    cancel.frame = NSRect(x: 370, y: 18, width: 130, height: 34)
    cancel.bezelStyle = .rounded
    cancel.keyEquivalent = "\u{1b}"
    content.addSubview(cancel)
    let capture = NSButton(title: "Foto aufnehmen", target: self, action: #selector(takePhoto))
    capture.frame = NSRect(x: 510, y: 18, width: 155, height: 34)
    capture.bezelStyle = .rounded
    capture.isEnabled = false
    content.addSubview(capture)
    captureButton = capture
    panel.contentView = content
    self.panel = panel
    parent?.beginSheet(panel)
    queue.async { [weak self] in
      guard let self = self else { return }
      self.session.startRunning()
      DispatchQueue.main.async {
        guard self.completion != nil else { return }
        if self.session.isRunning { self.captureButton?.isEnabled = true }
        else {
          self.finish(FlutterError(code: "camera_unavailable", message:
            "Kamera konnte nicht gestartet werden. Bitte ein Foto auswählen.", details: nil))
        }
      }
    }
  }

  @objc private func cancelPhoto() { finish(nil) }

  func cancel() { finish(nil) }

  @objc private func takePhoto() {
    captureButton?.isEnabled = false
    output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
  }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                   error: Error?) {
    let data = error == nil ? photo.fileDataRepresentation() : nil
    DispatchQueue.main.async { [weak self] in
      guard let data = data else {
        self?.finish(FlutterError(code: "capture_failed", message:
          "Foto konnte nicht aufgenommen werden. Bitte erneut versuchen.", details: nil))
        return
      }
      self?.finish(FlutterStandardTypedData(bytes: data))
    }
  }

  private func finish(_ value: Any?) {
    guard let callback = completion else { return }
    completion = nil
    if let panel = panel { parent?.endSheet(panel); panel.orderOut(nil) }
    let session = self.session
    queue.async { if session.isRunning { session.stopRunning() } }
    callback(value)
  }
}
