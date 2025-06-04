import ARKit
import Foundation
import PosePlugin
import RealityKit

// MARK: - Localization Response
public struct LocalizationResponse: Equatable {
  public let mapId: Int
  public let position: simd_float3
  public let rotation: simd_quatf
  public let confidence: Float

  public init(mapId: Int, position: simd_float3, rotation: simd_quatf, confidence: Float) {
    self.mapId = mapId
    self.position = position
    self.rotation = rotation
    self.confidence = confidence
  }

  internal init(from localizeInfo: LocalizeInfo, mapId: MapId) {
    self.mapId = mapId
    self.position = simd_float3(
      localizeInfo.position.x,
      localizeInfo.position.y,
      localizeInfo.position.z
    )
    self.rotation = simd_quatf(
      ix: localizeInfo.rotation.x,
      iy: localizeInfo.rotation.y,
      iz: localizeInfo.rotation.z,
      r: localizeInfo.rotation.w
    )
    self.confidence = Float(localizeInfo.confidence)
  }
}

// MARK: - Localizer Protocol

public protocol ImmersalLocalizer {
  func localizeImage(
    mapIds: [MapId],
    pixelBuffer: CVPixelBuffer,
    cameraParams: CameraParameters
  ) async -> Result<LocalizationResponse, ImmersalKitError>
  
  /// Returns the map IDs required for this localizer
  /// - Parameter mapManager: The map manager instance
  /// - Returns: Array of map IDs that should be used for localization
  func getRequiredMapIds(from mapManager: MapManager) -> [MapId]
}

// MARK: - Localizer Extensions

extension ImmersalLocalizer {
  /// Transforms result to matrix
  public func transformResultToMatrix(_ result: LocalizationResult) -> simd_float4x4 {
    let translationMatrix = simd_float4x4(
      columns: (
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(result.position.x, result.position.y, result.position.z, 1)
      ))
    let rotationMatrix = simd_float4x4(result.rotation)

    return translationMatrix * rotationMatrix
  }

  /// Transforms result using map entry spatial relation
  public func transformResult(_ result: LocalizationResult, using mapEntry: MapEntry)
    -> simd_float4x4
  {
    let resultMatrix = transformResultToMatrix(result)
    return mapEntry.relation.matrix() * resultMatrix
  }
}

// MARK: - Localization Result

public struct LocalizationResult {
  public let mapId: MapId
  public let position: simd_float3
  public let rotation: simd_quatf
  public let confidence: Float
  public let timestamp: TimeInterval
  public let cameraToWorldTransform: simd_float4x4
}

public enum LocalizationEvent {
  case started
  case result(LocalizationResult)
  case failed(ImmersalKitError)
  case stopped
}

extension LocalizationResult {
  /// Normalized confidence value (0.0-1.0)
  public func normalizedConfidence() -> Float {
    return min(max(confidence / 100.0, 0.0), 1.0)
  }
}
