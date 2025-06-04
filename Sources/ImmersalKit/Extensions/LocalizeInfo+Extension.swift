import Foundation
import PosePlugin
import simd

/// Extension providing convenient access to LocalizeInfo pose data.
///
/// This extension bridges between PosePlugin's native C++ types and Swift's SIMD types,
/// providing a more convenient and type-safe interface for working with localization results.
extension LocalizeInfo {
  /// Extracts position and rotation from localization result as Swift SIMD types.
  ///
  /// Converts PosePlugin's native types (`PPVector3`, `PPQuaternion`) to Swift's
  /// SIMD types (`simd_float3`, `simd_quatf`) for easier integration with
  /// RealityKit, ARKit, and other Swift frameworks.
  /// - Returns: Tuple containing position vector and rotation quaternion
  public var pose: (position: simd_float3, rotation: simd_quatf) {
    let position = simd_float3(
      self.position.x,
      self.position.y,
      self.position.z
    )

    let rotation = simd_quatf(
      ix: self.rotation.x,
      iy: self.rotation.y,
      iz: self.rotation.z,
      r: self.rotation.w
    )

    return (position, rotation)
  }
}
