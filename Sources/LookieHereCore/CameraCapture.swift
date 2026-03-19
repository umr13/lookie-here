import AVFoundation

public final class CameraCapture: NSObject {
    public typealias FrameHandler = (CMSampleBuffer) -> Void

    public let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.lookie-here.camera")
    private var frameHandler: FrameHandler?
    private var targetFps: Int

    public init(fps: Int = 10) {
        self.targetFps = fps
        super.init()
    }

    public func start(handler: @escaping FrameHandler) throws {
        frameHandler = handler

        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .unspecified
        ) else {
            throw CameraCaptureError.noCamera
        }

        // Configure frame rate — clamp to device's supported range
        try device.lockForConfiguration()
        let clampedFps = clampFps(targetFps, for: device)
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(clampedFps))
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(clampedFps))
        device.unlockForConfiguration()

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraCaptureError.cannotAddInput
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            throw CameraCaptureError.cannotAddOutput
        }
        session.addOutput(output)

        session.startRunning()
    }

    public func stop() {
        session.stopRunning()
    }

    /// Resume a previously started session (inputs/outputs already configured).
    public func restart() {
        session.startRunning()
    }

    public func updateFps(_ fps: Int) {
        targetFps = fps
        guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        try? device.lockForConfiguration()
        let clampedFps = clampFps(fps, for: device)
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(clampedFps))
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(clampedFps))
        device.unlockForConfiguration()
    }

    /// Clamp desired FPS to the device's supported range.
    private func clampFps(_ fps: Int, for device: AVCaptureDevice) -> Int {
        guard let range = device.activeFormat.videoSupportedFrameRateRanges.first else {
            return fps
        }
        let minFps = Int(ceil(range.minFrameRate))
        let maxFps = Int(floor(range.maxFrameRate))
        return max(minFps, min(fps, maxFps))
    }
}

extension CameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameHandler?(sampleBuffer)
    }
}

public enum CameraCaptureError: Error, LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput

    public var errorDescription: String? {
        switch self {
        case .noCamera: return "No built-in camera found"
        case .cannotAddInput: return "Cannot add camera input to session"
        case .cannotAddOutput: return "Cannot add video output to session"
        }
    }
}
