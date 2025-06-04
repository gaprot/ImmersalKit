import Foundation
import RealityKit

/// Structure that encapsulates data needed for coordinate transformations
public struct SceneUpdateData {
  /// Final transformation matrix
  public let pose: simd_float4x4

  /// Tracker space matrix
  public let trackerSpace: simd_float4x4

  /// Map space matrix
  public let mapSpacePose: simd_float4x4

  /// Localization information
  public let localizeInfo: LocalizationResult

  /// Map entry
  public let mapEntry: MapEntry

  /// Initialize
  /// - Parameters:
  ///   - localizeInfo: Localization result
  ///   - trackerSpace: Tracker space matrix
  ///   - mapEntry: Map entry
  public init(localizeInfo: LocalizationResult, trackerSpace: simd_float4x4, mapEntry: MapEntry) {
    self.localizeInfo = localizeInfo
    self.trackerSpace = trackerSpace
    self.mapEntry = mapEntry

    // Calculate pose in map space
    let rotationMatrix = simd_float4x4(localizeInfo.rotation)
    // Create translation matrix
    let translationMatrix = simd_float4x4(
      SIMD4<Float>(1, 0, 0, 0),
      SIMD4<Float>(0, 1, 0, 0),
      SIMD4<Float>(0, 0, 1, 0),
      SIMD4<Float>(localizeInfo.position.x, localizeInfo.position.y, localizeInfo.position.z, 1)
    )
    self.mapSpacePose = translationMatrix * rotationMatrix

    // Calculate final transformation matrix
    // trackerSpace * mapSpacePose * mapEntry.inverseMatrix()
    self.pose = trackerSpace * mapSpacePose * mapEntry.inverseMatrix()
  }

  /// Alternative initialization method - directly specify each matrix
  /// - Parameters:
  ///   - pose: Final transformation matrix
  ///   - trackerSpace: Tracker space matrix
  ///   - mapSpacePose: Map space matrix
  ///   - localizeInfo: Localization information
  ///   - mapEntry: Map entry
  public init(
    pose: simd_float4x4, trackerSpace: simd_float4x4, mapSpacePose: simd_float4x4,
    localizeInfo: LocalizationResult, mapEntry: MapEntry
  ) {
    self.pose = pose
    self.trackerSpace = trackerSpace
    self.mapSpacePose = mapSpacePose
    self.localizeInfo = localizeInfo
    self.mapEntry = mapEntry
  }

  /// Apply transformation matrix to entity
  /// - Parameter entity: Entity to apply transformation to
  @MainActor
  public func applyTransform(to entity: Entity) {
    entity.transform = Transform(matrix: pose)
  }

  // MARK: - Final Scene Coordinate Transformations

  /// Transform point from map space to final scene space
  ///
  /// This transformation applies trackerSpace * mapSpacePose * mapEntry.inverseMatrix(),
  /// providing final scene placement that reflects localization results and tracker space adjustments.
  ///
  /// - Parameter point: Point in map space
  /// - Returns: Point in final scene space
  public func transformPointToFinalScene(_ point: simd_float3) -> simd_float3 {
    let homogeneousPoint = SIMD4<Float>(point.x, point.y, point.z, 1)
    let transformedPoint = pose * homogeneousPoint
    return simd_float3(transformedPoint.x, transformedPoint.y, transformedPoint.z)
      / transformedPoint.w
  }

  /// Transform point from final scene space to map space
  ///
  /// Performs inverse transformation of transformPointToFinalScene(_:).
  ///
  /// - Parameter point: Point in final scene space
  /// - Returns: Point in map space
  public func transformPointFromFinalScene(_ point: simd_float3) -> simd_float3 {
    let inversePose = simd_inverse(pose)
    let homogeneousPoint = SIMD4<Float>(point.x, point.y, point.z, 1)
    let transformedPoint = inversePose * homogeneousPoint
    return simd_float3(transformedPoint.x, transformedPoint.y, transformedPoint.z)
      / transformedPoint.w
  }

  /// Transform rotation from map space to final scene space
  ///
  /// - Parameter rotation: Rotation in map space
  /// - Returns: Rotation in final scene space
  public func transformRotationToFinalScene(_ rotation: simd_quatf) -> simd_quatf {
    let poseRotation = simd_quatf(pose)
    return poseRotation * rotation
  }

  /// Transform rotation from final scene space to map space
  ///
  /// - Parameter rotation: Rotation in final scene space
  /// - Returns: Rotation in map space
  public func transformRotationFromFinalScene(_ rotation: simd_quatf) -> simd_quatf {
    let poseRotation = simd_quatf(pose)
    return poseRotation.inverse * rotation
  }
}
