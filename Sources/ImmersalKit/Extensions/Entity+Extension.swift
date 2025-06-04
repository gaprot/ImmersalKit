import Foundation
import RealityKit

extension Entity {
  /// Get local to world transformation matrix
  /// - Returns: Transformation matrix from local to world coordinates
  internal func localToWorldMatrix() -> simd_float4x4 {
    // Specify nil to get transformation matrix relative to world coordinate system
    return self.transformMatrix(relativeTo: nil)
  }

  /// Get transformation matrix relative to reference entity
  /// - Parameter referenceEntity: Reference entity (nil for world coordinates)
  /// - Returns: Relative transformation matrix from specified reference entity
  internal func localToMatrix(relativeTo referenceEntity: Entity?) -> simd_float4x4 {
    return self.transformMatrix(relativeTo: referenceEntity)
  }

  /// Get local transformation matrix relative to parent entity
  /// - Returns: Local transformation matrix relative to parent entity
  internal func localMatrix() -> simd_float4x4 {
    if let parent = self.parent {
      // When parent exists, return relative transformation matrix based on parent
      return self.transformMatrix(relativeTo: parent)
    } else {
      // When no parent exists, same as world transformation matrix
      return self.transformMatrix(relativeTo: nil)
    }
  }
}
