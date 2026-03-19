import Vision
import CoreMedia
import CoreVideo

public struct FaceDirection {
    public let yaw: Double   // radians, negative = left, positive = right
    public let pitch: Double // radians, negative = down, positive = up

    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }
}

public final class FaceTracker {
    public typealias FaceHandler = (FaceDirection?) -> Void

    private let sequenceHandler = VNSequenceRequestHandler()
    private let request: VNDetectFaceLandmarksRequest
    var verbose: Bool = false

    /// Completion handler set per-frame before perform().
    private var currentCompletion: FaceHandler?

    public init() {
        request = VNDetectFaceLandmarksRequest()
    }

    /// Process a camera frame and call the handler with the detected face direction, or nil if no face.
    public func process(sampleBuffer: CMSampleBuffer, completion: @escaping FaceHandler) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            if verbose { print("[FACE_TRACKER] No pixel buffer in sample") }
            completion(nil)
            return
        }

        do {
            // Use .leftMirrored for FaceTime camera on Mac (front-facing, mirrored)
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .leftMirrored)
        } catch {
            if verbose { print("[FACE_TRACKER] perform() failed: \(error)") }
            completion(nil)
            return
        }

        guard let face = request.results?.first else {
            if verbose { print("[FACE_TRACKER] No faces in results") }
            completion(nil)
            return
        }

        guard let yawNumber = face.yaw else {
            if verbose { print("[FACE_TRACKER] Face found but no yaw") }
            completion(nil)
            return
        }

        let pitch = face.pitch?.doubleValue ?? 0.0

        if verbose {
            print("[FACE_TRACKER] Face: yaw=\(String(format: "%+.2f", yawNumber.doubleValue)) pitch=\(String(format: "%+.2f", pitch))")
        }

        let direction = FaceDirection(
            yaw: yawNumber.doubleValue,
            pitch: pitch
        )
        completion(direction)
    }
}
