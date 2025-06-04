import ARKit
import Combine
import Foundation
import PosePlugin
import QuartzCore
import RealityKit

/// PosePlugin-based localizer (without retry functionality)
public final class PosePluginLocalizer: ImmersalLocalizer {
  private var intrinsicsBuffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: 4)
  private let errorReporter: ErrorReporting

  public init(errorReporter: ErrorReporting = DefaultErrorReporter()) {
    self.errorReporter = errorReporter
  }

  deinit {
    intrinsicsBuffer.deallocate()
  }
  
  public func getRequiredMapIds(from mapManager: MapManager) -> [MapId] {
    // PosePlugin requires actually loaded map data in memory
    return Array(mapManager.loadedMaps.keys)
  }

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

    let width = Int32(CVPixelBufferGetWidth(pixelBuffer))
    let height = Int32(CVPixelBufferGetHeight(pixelBuffer))

    guard width > 0 && height > 0 else {
      let error = ImmersalKitError.imageProcessing(
        .invalidPixelBuffer("Invalid image dimensions: \(width)x\(height)"))
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["width": width, "height": height]))
      return .failure(error)
    }

    switch updateBuffer(cameraParams) {
    case .success:
      break
    case .failure(let error):
      return .failure(error)
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer {
      CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }

    guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
      let error = ImmersalKitError.localization(.pixelBufferProcessingFailed)
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["pixelBuffer": "Y plane access failed"]))
      return .failure(error)
    }

    let channels: Int32 = 1
    let solverType: Int32 = 0
    var cameraRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    let locInfo = Core.localizeImage(
      mapIds: mapIds,
      width: width,
      height: height,
      intrinsics: intrinsicsBuffer.baseAddress!,
      pixels: baseAddress,
      channels: channels,
      solverType: solverType,
      cameraRotation: &cameraRotation
    )

    if locInfo.handle < 0 {
      let error = ImmersalKitError.localization(
        .coreLocalizationFailed("Invalid handle: \(locInfo.handle)"))
      errorReporter.reportError(
        error,
        context: ErrorContext(additionalInfo: [
          "handle": locInfo.handle, "confidence": locInfo.confidence,
        ]))
      return .failure(error)
    }

    if locInfo.confidence <= 0 {
      let error = ImmersalKitError.localization(
        .coreLocalizationFailed("Low confidence: \(locInfo.confidence)"))
      errorReporter.reportError(
        error,
        context: ErrorContext(additionalInfo: [
          "handle": locInfo.handle, "confidence": locInfo.confidence,
        ]))
      return .failure(error)
    }

    guard let mapId = MapHandleMapping.getMapId(for: locInfo.handle) else {
      let error = ImmersalKitError.localization(
        .coreLocalizationFailed("Failed to get mapId for handle: \(locInfo.handle)"))
      errorReporter.reportError(
        error, context: ErrorContext(additionalInfo: ["handle": locInfo.handle]))
      return .failure(error)
    }

    let result = LocalizationResponse(from: locInfo, mapId: mapId)
    return .success(result)
  }

  private func updateBuffer(_ cameraParams: CameraParameters) -> Result<Void, ImmersalKitError> {
    guard cameraParams.fx > 0 && cameraParams.fy > 0 else {
      let error = ImmersalKitError.localization(.invalidCameraParameters)
      errorReporter.reportError(
        error,
        context: ErrorContext(additionalInfo: [
          "fx": cameraParams.fx,
          "fy": cameraParams.fy,
          "ox": cameraParams.ox,
          "oy": cameraParams.oy,
        ]))
      return .failure(error)
    }

    let validRange = 1.0...10000.0
    guard validRange.contains(cameraParams.fx) && validRange.contains(cameraParams.fy) else {
      let error = ImmersalKitError.localization(.invalidCameraParameters)
      errorReporter.reportError(
        error,
        context: ErrorContext(additionalInfo: [
          "fx": cameraParams.fx,
          "fy": cameraParams.fy,
          "reason": "Values out of valid range",
        ]))
      return .failure(error)
    }

    do {
      intrinsicsBuffer[0] = Float(cameraParams.fx)
      intrinsicsBuffer[1] = Float(cameraParams.fy)
      intrinsicsBuffer[2] = Float(cameraParams.ox)
      intrinsicsBuffer[3] = Float(cameraParams.oy)
      return .success(())
    } catch {
      let immersalError = ImmersalKitError.localization(.intrinsicsInitializationFailed)
      errorReporter.reportError(
        immersalError, context: ErrorContext(additionalInfo: ["underlying_error": error]))
      return .failure(immersalError)
    }
  }
}
