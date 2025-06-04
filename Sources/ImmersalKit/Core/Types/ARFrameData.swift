import ARKit
import CoreImage
import Foundation

/// AR camera frame data structure
///
/// Holds image data and camera parameters from camera frames
/// obtained from AR sessions.
///
/// This property is declared as `let` and never modified after initialization, so it's safe to share between threads.
/// Also, `CVPixelBuffer` is reference counted, so read access from multiple threads should be safe
public struct ARFrameData: @unchecked Sendable {
  /// Camera pixel buffer
  public let pixelBuffer: CVPixelBuffer

  /// Capture time
  public let captureTime: TimeInterval

  /// Camera intrinsic parameters (focal length, principal point, etc.)
  public let cameraIntrinsics: simd_float3x3

  /// Camera extrinsic parameters (camera to device transformation matrix)
  public let cameraExtrinsics: simd_float4x4

  /// Generate CIImage from pixel buffer
  public var ciImage: CIImage? {
    return CIImage(cvPixelBuffer: pixelBuffer)
  }

  /// Image width
  public var width: Int {
    return CVPixelBufferGetWidth(pixelBuffer)
  }

  /// Image height
  public var height: Int {
    return CVPixelBufferGetHeight(pixelBuffer)
  }

  /// Get image resolution as string
  public var resolution: String {
    return "\(width) x \(height)"
  }
}
