import Foundation
import RealityKit
import SwiftUI

/// Encapsulates a map and its transformation information
public struct MapEntry {
  /// Map identifier
  public let mapId: MapId

  /// Spatial relationship information
  public var relation: MapToSpaceRelation

  /// Scene entity reference
  public var sceneParent: Entity?

  public init(
    mapId: MapId,
    relation: MapToSpaceRelation = MapToSpaceRelation(),
    sceneParent: Entity? = nil
  ) {
    self.mapId = mapId
    self.relation = relation
    self.sceneParent = sceneParent
  }

  /// Get transformation matrix
  public func matrix() -> simd_float4x4 {
    return relation.matrix()
  }

  /// Get inverse transformation matrix
  public func inverseMatrix() -> simd_float4x4 {
    return relation.inverseMatrix()
  }

  /// Transform point from map space to world space
  public func transformPoint(_ point: simd_float3) -> simd_float3 {
    return relation.transformPoint(point)
  }

  /// Transform point from world space to map space
  public func inverseTransformPoint(_ point: simd_float3) -> simd_float3 {
    return relation.inverseTransformPoint(point)
  }

  /// Transform rotation from map space to world space
  public func transformRotation(_ rotation: simd_quatf) -> simd_quatf {
    return relation.transformRotation(rotation)
  }

  /// Transform rotation from world space to map space
  public func inverseTransformRotation(_ rotation: simd_quatf) -> simd_quatf {
    return relation.inverseTransformRotation(rotation)
  }

  /// Apply transformation to scene parent entity
  @MainActor @discardableResult
  public func applyTransformToScene() -> Bool {
    guard let sceneParent = sceneParent else {
      return false
    }

    relation.applyToEntity(sceneParent)
    return true
  }

}
