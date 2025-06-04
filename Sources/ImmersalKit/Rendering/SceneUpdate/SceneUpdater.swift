import Foundation
import RealityKit

/// Class for applying localization results to 3D space
public final class SceneUpdater {
  // State management
  private(set) var lastUpdateData: SceneUpdateData?

  /// Initialize
  public init() {}

  /// Update scene
  /// - Parameters:
  ///   - entry: Map entry
  ///   - result: Localization result
  ///   - deviceToWorldTransform: Device to world transformation matrix
  /// - Returns: Update data
  @discardableResult
  @MainActor
  public func updateScene(
    entry: MapEntry,
    result: LocalizationResult,
    deviceToWorldTransform: simd_float4x4
  ) async -> SceneUpdateData? {
    // Calculate coordinate transformations
    let mapLocalMatrix = simd_float4x4(
      position: result.position, rotation: result.rotation)

    // Inverse of map local matrix
    let mapLocalMatrixInv = mapLocalMatrix.inverse

    // Apply map relationship
    let mapSpacePose = entry.relation.matrix() * mapLocalMatrix

    await MainActor.run {
      if let entity = entry.sceneParent {
        entity.setPosition(.zero, relativeTo: nil)
        entity.setOrientation(.init(), relativeTo: nil)
        let finalTransform =
          result.cameraToWorldTransform * mapLocalMatrixInv
          * entity
          .transformMatrix(relativeTo: nil)
        entity.transform.matrix = finalTransform
        entity.position.y -= 0.25
        // Create SceneUpdateData
        let updateData = SceneUpdateData(
          pose: finalTransform,
          trackerSpace: deviceToWorldTransform,
          mapSpacePose: mapSpacePose,
          localizeInfo: result,
          mapEntry: entry
        )
        // Save update data
        lastUpdateData = updateData
      }
    }

    return lastUpdateData
  }

  /// Get last update data
  /// - Returns: Last SceneUpdateData
  public func getLastUpdateData() -> SceneUpdateData? {
    return lastUpdateData
  }

  /// Apply last update to specified entity
  /// - Parameter entity: Target entity
  /// - Returns: Whether application was successful
  @discardableResult
  @MainActor
  public func applyLastUpdateToEntity(_ entity: Entity) -> Bool {
    guard let updateData = lastUpdateData else {
      return false
    }

    updateData.applyTransform(to: entity)
    return true
  }

}
