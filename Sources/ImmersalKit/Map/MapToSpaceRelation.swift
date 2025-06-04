import Foundation
import RealityKit

/// Holds map position, rotation, and scale for coordinate transformations
public struct MapToSpaceRelation {
  /// Map position
  public var position: simd_float3

  /// Map rotation
  public var rotation: simd_quatf

  /// Map scale
  public var scale: simd_float3

  public init(
    position: simd_float3 = .zero,
    rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
    scale: simd_float3 = simd_float3(1, 1, 1)
  ) {
    self.position = position
    self.rotation = rotation
    self.scale = scale
  }

  /// Calculate transformation matrix
  public func matrix() -> simd_float4x4 {
    // Translation matrix
    let translationMatrix = simd_float4x4(
      SIMD4<Float>(1, 0, 0, 0),
      SIMD4<Float>(0, 1, 0, 0),
      SIMD4<Float>(0, 0, 1, 0),
      SIMD4<Float>(position.x, position.y, position.z, 1)
    )

    // Rotation matrix
    let rotationMatrix = simd_float4x4(rotation)

    // Scale matrix
    let scaleMatrix = simd_float4x4(diagonal: SIMD4<Float>(scale.x, scale.y, scale.z, 1))

    // Transform order: scale, rotation, translation
    return translationMatrix * rotationMatrix * scaleMatrix
  }

  /// Calculate inverse transformation matrix
  public func inverseMatrix() -> simd_float4x4 {
    // Inverse translation matrix
    let inverseTranslationMatrix = simd_float4x4(
      SIMD4<Float>(1, 0, 0, 0),
      SIMD4<Float>(0, 1, 0, 0),
      SIMD4<Float>(0, 0, 1, 0),
      SIMD4<Float>(-position.x, -position.y, -position.z, 1)
    )

    // Inverse rotation matrix
    let inverseRotationMatrix = simd_float4x4(rotation.inverse)

    // Inverse scale matrix
    let inverseScaleMatrix = simd_float4x4(
      diagonal: SIMD4<Float>(1 / scale.x, 1 / scale.y, 1 / scale.z, 1))

    // Inverse transform order: inverse translation, rotation, scale
    return inverseScaleMatrix * inverseRotationMatrix * inverseTranslationMatrix
  }

  /// Transform point from map space to world space
  public func transformPoint(_ point: simd_float3) -> simd_float3 {
    let transformMatrix = matrix()
    let homogeneousPoint = SIMD4<Float>(point.x, point.y, point.z, 1)
    let transformedPoint = transformMatrix * homogeneousPoint
    return simd_float3(transformedPoint.x, transformedPoint.y, transformedPoint.z)
      / transformedPoint.w
  }

  /// Transform point from world space to map space
  public func inverseTransformPoint(_ point: simd_float3) -> simd_float3 {
    let inverseTransformMatrix = inverseMatrix()
    let homogeneousPoint = SIMD4<Float>(point.x, point.y, point.z, 1)
    let transformedPoint = inverseTransformMatrix * homogeneousPoint
    return simd_float3(transformedPoint.x, transformedPoint.y, transformedPoint.z)
      / transformedPoint.w
  }

  /// Transform rotation from map space to world space
  public func transformRotation(_ rotation: simd_quatf) -> simd_quatf {
    return self.rotation * rotation
  }

  /// Transform rotation from world space to map space
  public func inverseTransformRotation(_ rotation: simd_quatf) -> simd_quatf {
    return self.rotation.inverse * rotation
  }

  /// Apply transformation matrix to entity
  @MainActor
  public func applyToEntity(_ entity: Entity) {
    entity.transform = Transform(matrix: matrix())
  }
}
