import ARKit
import Foundation

/// AR tracking data structure
///
/// Holds AR session tracking state and device position/orientation information.
/// This data is primarily used in localization processing.
public struct ARTrackingData: Sendable {

  /// Device to world coordinate transformation matrix
  public let device2World: simd_float4x4

  /// Current tracking state
  public let trackingState: DataProviderState

  /// Data timestamp
  public let timestamp: TimeInterval

  /// Device position (world coordinates)
  public var position: simd_float3 {
    return simd_float3(device2World.columns.3.x, device2World.columns.3.y, device2World.columns.3.z)
  }

  /// Device rotation (world coordinates)
  public var rotation: simd_quatf {
    return simd_quatf(device2World)
  }

  /// Tracking state description
  public var trackingStateDescription: String {
    return trackingState.description
  }
}
