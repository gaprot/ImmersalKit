import ARKit
import Combine
import Foundation
import PosePlugin
import QuartzCore
import RealityKit

/// REST API-based localizer (without retry functionality)
public final class RestApiLocalizer: ImmersalLocalizer {
  private var immersalClient: ImmersalAPI
  private let errorReporter: ErrorReporting

  public init(api: ImmersalAPI, errorReporter: ErrorReporting = DefaultErrorReporter()) {
    self.immersalClient = api
    self.errorReporter = errorReporter
  }
  
  public func getRequiredMapIds(from mapManager: MapManager) -> [MapId] {
    // REST API only needs map IDs, not the actual map data
    return Array(mapManager.mapEntries.keys)
  }

  /// Localizes an image using the REST API
  public func localizeImage(
    mapIds: [MapId],
    pixelBuffer: CVPixelBuffer,
    cameraParams: CameraParameters
  ) async -> Result<LocalizationResponse, ImmersalKitError> {

    guard !mapIds.isEmpty else {
      let error = ImmersalKitError.localization(.invalidMapIds)
      errorReporter.reportError(error, context: ErrorContext(additionalInfo: ["mapIds": mapIds]))
      return .failure(error)
    }

    let b64Result = await convertPixelBufferToBase64(pixelBuffer)
    let b64: String

    switch b64Result {
    case .success(let base64String):
      b64 = base64String
    case .failure(let error):
      return .failure(error)
    }

    do {
      let response = try await immersalClient.localizeImage(
        b64: b64,
        mapIds: mapIds,
        cameraParams: cameraParams
      )

      return processApiResponse(response)

    } catch let error as ImmersalError {
      let immersalKitError = ImmersalKitError.network(error)
      errorReporter.reportError(
        immersalKitError, context: ErrorContext(additionalInfo: ["mapIds": mapIds]))
      return .failure(immersalKitError)

    } catch {
      let immersalKitError = ImmersalKitError.localization(
        .networkError(error.localizedDescription))
      errorReporter.reportError(
        immersalKitError, context: ErrorContext(additionalInfo: ["underlying_error": error]))
      return .failure(immersalKitError)
    }
  }

  /// Converts pixel buffer to Base64 string
  private func convertPixelBufferToBase64(_ pixelBuffer: CVPixelBuffer) async -> Result<
    String, ImmersalKitError
  > {
    do {
      let b64String = try await pixelBuffer.toBase64EncodedPNG()

      guard !b64String.isEmpty else {
        let error = ImmersalKitError.imageProcessing(.conversionFailed("Empty base64 string"))
        errorReporter.reportError(error, context: ErrorContext())
        return .failure(error)
      }

      if b64String.count > 10_000_000 {
        let context = ErrorContext(additionalInfo: ["base64_size": b64String.count])
      }

      return .success(b64String)

    } catch let error as ImageConversionError {
      let immersalKitError = ImmersalKitError.imageProcessing(error)
      errorReporter.reportError(immersalKitError, context: ErrorContext())
      return .failure(immersalKitError)

    } catch {
      let immersalKitError = ImmersalKitError.imageProcessing(
        .conversionFailed(error.localizedDescription))
      errorReporter.reportError(
        immersalKitError, context: ErrorContext(additionalInfo: ["underlying_error": error]))
      return .failure(immersalKitError)
    }
  }

  /// Processes API response
  private func processApiResponse(_ response: LocalizeResponse) -> Result<
    LocalizationResponse, ImmersalKitError
  > {
    guard response.isSuccess else {
      let localizationError: LocalizationError

      switch response.error {
      case "auth":
        localizationError = .authenticationFailed
      case "invalid":
        localizationError = .invalidResponse
      case "none":
        localizationError = .invalidResponse
      default:
        localizationError = .serverError(response.error)
      }

      let error = ImmersalKitError.localization(localizationError)
      errorReporter.reportError(
        error,
        context: ErrorContext(additionalInfo: [
          "response_error": response.error,
          "response_success": response.success ?? false,
        ]))
      return .failure(error)
    }

    let pose = response.pose

    guard let mapId = response.map else {
      let error = ImmersalKitError.localization(.invalidResponse)
      errorReporter.reportError(error, context: ErrorContext(additionalInfo: ["missing": "mapId"]))
      return .failure(error)
    }

    guard let position = pose.0 else {
      let error = ImmersalKitError.localization(.invalidResponse)
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["missing": "position"]))
      return .failure(error)
    }

    guard let rotation = pose.1 else {
      let error = ImmersalKitError.localization(.invalidResponse)
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["missing": "rotation"]))
      return .failure(error)
    }

    // NOTE: Hardcoded confidence value because the Immersal REST API response
    // does not include confidence information, unlike the PosePlugin which provides
    // actual confidence scores. This is a known limitation of the REST API endpoint.
    let confidence: Float = 100.0

    if !isValidPosition(position) {
      let error = ImmersalKitError.localization(.invalidResponse)
      errorReporter.reportError(
        error,
        context: ErrorContext(additionalInfo: [
          "position": [position.x, position.y, position.z],
          "reason": "Invalid position values",
        ]))
      return .failure(error)
    }

    if !isValidQuaternion(rotation) {
      let error = ImmersalKitError.localization(.invalidResponse)
      errorReporter.reportError(
        error,
        context: ErrorContext(additionalInfo: [
          "rotation": [rotation.vector.x, rotation.vector.y, rotation.vector.z, rotation.vector.w],
          "reason": "Invalid quaternion values",
        ]))
      return .failure(error)
    }

    let result = LocalizationResponse(
      mapId: mapId,
      position: position,
      rotation: rotation,
      confidence: confidence
    )

    return .success(result)
  }

  /// Validates position values
  private func isValidPosition(_ position: simd_float3) -> Bool {
    guard position.x.isFinite && position.y.isFinite && position.z.isFinite else {
      return false
    }

    let magnitude = simd_length(position)
    return magnitude < 100_000.0
  }

  /// Validates quaternion values
  private func isValidQuaternion(_ quaternion: simd_quatf) -> Bool {
    let components = [
      quaternion.vector.x, quaternion.vector.y, quaternion.vector.z, quaternion.vector.w,
    ]

    guard components.allSatisfy({ $0.isFinite }) else {
      return false
    }

    let length = simd_length(quaternion)
    return abs(length - 1.0) < 0.1
  }
}
