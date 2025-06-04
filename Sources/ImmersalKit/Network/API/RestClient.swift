import ARKit
import Combine
import Foundation
import PosePlugin
import QuartzCore
import RealityKit

public class RestClient: ImmersalAPI {
  // MARK: - Properties

  public var tokenProvider: TokenProvider

  private let baseURL = "https://api.immersal.com"
  private var session: URLSessionProtocol

  // MARK: - Initialization

  public init(
    session: URLSessionProtocol = URLSession.shared,
    tokenProvider: TokenProvider = SecureTokenProvider()
  ) {
    self.session = session
    self.tokenProvider = tokenProvider
  }

  // MARK: - Authentication Methods

  public func login(username: String, password: String) async throws -> LoginResponse {
    let request = LoginRequest(login: username, password: password)
    let response: LoginResponse = try await performRequest(endpoint: "/login", body: request)

    if response.isSuccess, let token = response.token {
      tokenProvider.setToken(token)
    }

    return response
  }

  public func getStatus() async throws -> StatusResponse {
    guard let token = tokenProvider.token else {
      throw ImmersalError.missingToken
    }

    let request = StatusRequest(token: token)
    return try await performRequest(endpoint: "/status", body: request)
  }

  // MARK: - Map Management Methods

  public func listMaps() async throws -> [Job] {
    guard let token = tokenProvider.token else {
      throw ImmersalError.missingToken
    }

    let request = ListRequest(token: token)
    let response: JobsResponse = try await performRequest(endpoint: "/list", body: request)

    guard let jobs = response.jobs else {
      return []
    }

    return jobs
  }

  public func downloadMap(mapId: Int) async throws -> Data {
    guard let token = tokenProvider.token else {
      throw ImmersalError.missingToken
    }

    let urlString = "\(baseURL)/map?id=\(mapId)"

    guard let url = URL(string: urlString) else {
      throw ImmersalError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ImmersalError.invalidResponse
    }

    if httpResponse.statusCode != 200 {
      if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
        throw ImmersalError.apiError(errorResponse.error)
      } else {
        throw ImmersalError.httpError(httpResponse.statusCode)
      }
    }

    return data
  }

  // MARK: - Localization Methods

  public func localizeImage(
    b64: String,
    mapIds: [Int],
    cameraParams: CameraParameters
  ) async throws -> LocalizeResponse {
    guard let token = tokenProvider.token else {
      throw ImmersalError.missingToken
    }

    let request = LocalizeB64Request(
      mapIds: mapIds,
      b64: b64,
      oy: cameraParams.oy,
      ox: cameraParams.ox,
      fy: cameraParams.fy,
      token: token,
      fx: cameraParams.fx
    )

    return try await performRequest(endpoint: "/localizeb64", body: request)
  }

  // MARK: - Utility Methods

  public func getVersion() async throws -> String {
    let urlString = "\(baseURL)/version"

    guard let url = URL(string: urlString) else {
      throw ImmersalError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw ImmersalError.invalidResponse
    }

    if httpResponse.statusCode != 200 {
      if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
        throw ImmersalError.apiError(errorResponse.error)
      } else {
        throw ImmersalError.httpError(httpResponse.statusCode)
      }
    }

    do {
      let versionResponse = try JSONDecoder().decode(VersionResponse.self, from: data)
      return versionResponse.version ?? "Unknown"
    } catch {
      throw ImmersalError.decodingError(error)
    }
  }

  private func performRequest<U: Decodable>(
    endpoint: String,
    body: some Encodable
  ) async throws -> U {
    let urlString = baseURL + endpoint

    guard let url = URL(string: urlString) else {
      throw ImmersalError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    do {
      let jsonEncoder = JSONEncoder()
      jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      request.httpBody = try jsonEncoder.encode(body)
    } catch {
      throw ImmersalError.encodingError(error)
    }

    do {
      let (data, response) = try await session.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw ImmersalError.invalidResponse
      }

      if httpResponse.statusCode != 200 {
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
          throw ImmersalError.apiError(errorResponse.error)
        } else {
          throw ImmersalError.httpError(httpResponse.statusCode)
        }
      }

      do {
        return try JSONDecoder().decode(U.self, from: data)
      } catch {
        throw ImmersalError.decodingError(error)
      }
    } catch let error as ImmersalError {
      throw error
    } catch {
      throw ImmersalError.networkError(error)
    }
  }
}
