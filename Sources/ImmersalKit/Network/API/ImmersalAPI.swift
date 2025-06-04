import Foundation

/// Protocol for Immersal API
public protocol ImmersalAPI {
  var tokenProvider: TokenProvider { get set }

  // Authentication
  func login(username: String, password: String) async throws -> LoginResponse
  func getStatus() async throws -> StatusResponse

  // Map management
  func listMaps() async throws -> [Job]
  func downloadMap(mapId: Int) async throws -> Data

  // Localization
  func localizeImage(
    b64: String,
    mapIds: [Int],
    cameraParams: CameraParameters
  ) async throws -> LocalizeResponse

  // Utility
  func getVersion() async throws -> String
}
