//
//  ImmersalError.swift
//  ImmersalKit
//
//  Created by ryudai.kimura on 2025/05/27.
//

import ARKit
import Foundation

/// Network and API communication errors for Immersal services.
public enum ImmersalError: Error, LocalizedError, Equatable {
  case missingToken
  case invalidURL
  case networkError(Error)
  case encodingError(Error)
  case decodingError(Error)
  case invalidResponse
  case httpError(Int)
  case apiError(String)
  case noData

  public var errorDescription: String? {
    switch self {
    case .missingToken:
      return "Developer token is not configured"
    case .invalidURL:
      return "Invalid URL"
    case let .networkError(error):
      return "Network error: \(error.localizedDescription)"
    case let .encodingError(error):
      return "Data encoding error: \(error.localizedDescription)"
    case let .decodingError(error):
      return "Data decoding error: \(error.localizedDescription)"
    case .invalidResponse:
      return "Invalid response"
    case let .httpError(code):
      return "HTTP error: \(code)"
    case let .apiError(message):
      return "API error: \(message)"
    case .noData:
      return "No data available"
    }
  }

  public var failureReason: String? {
    switch self {
    case .missingToken:
      return "Token required for Immersal API usage is not configured"
    case .invalidURL:
      return "Request URL format is incorrect"
    case .networkError(let error):
      return "An error occurred during network communication: \(error.localizedDescription)"
    case .encodingError(let error):
      return "An error occurred while encoding request data: \(error.localizedDescription)"
    case .decodingError(let error):
      return "An error occurred while decoding response data: \(error.localizedDescription)"
    case .invalidResponse:
      return "Server response is not in the expected format"
    case .httpError(let code):
      return "Server returned HTTP error code \(code)"
    case .apiError(let message):
      return "An error occurred during API processing: \(message)"
    case .noData:
      return "No response data was returned from the server"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .missingToken:
      return "Please add the ImmersalToken key to Info.plist or set the developer token in code."
    case .invalidURL:
      return "Please check the API endpoint URL configuration."
    case .networkError(_):
      return "Please check your internet connection and wait a moment before retrying."
    case .encodingError(_):
      return "Please check the format of the data being sent and use valid parameters."
    case .decodingError(_):
      return "The API response format may have changed. Please check the library version."
    case .invalidResponse:
      return "Please verify that the API endpoint is correct and contact support if necessary."
    case .httpError(let code):
      return getHTTPErrorRecoverySuggestion(for: code)
    case .apiError(_):
      return
        "Please check the API documentation and verify that you are using the correct parameters."
    case .noData:
      return "Please check your network connection and verify that the API endpoint is available."
    }
  }

  /// Provides specific recovery suggestions for HTTP error codes.
  private func getHTTPErrorRecoverySuggestion(for code: Int) -> String {
    switch code {
    case 400:
      return "Please check your request parameters."
    case 401:
      return "Please check your authentication token and re-login if necessary."
    case 403:
      return "Please check your access permissions."
    case 404:
      return "Please check the API endpoint URL."
    case 429:
      return "Please reduce request frequency and wait before retrying."
    case 500...599:
      return "This is a server-side issue. Please wait and try again later."
    default:
      return "For details about HTTP status code \(code), please refer to the API documentation."
    }
  }

  public static func == (lhs: ImmersalError, rhs: ImmersalError) -> Bool {
    switch (lhs, rhs) {
    case (.missingToken, .missingToken),
      (.invalidURL, .invalidURL),
      (.invalidResponse, .invalidResponse),
      (.noData, .noData):
      return true
    case (.networkError, .networkError),
      (.encodingError, .encodingError),
      (.decodingError, .decodingError):
      return true  // Error types cannot be compared, so treat same types as equal
    case let (.httpError(lhsCode), .httpError(rhsCode)):
      return lhsCode == rhsCode
    case let (.apiError(lhsMessage), .apiError(rhsMessage)):
      return lhsMessage == rhsMessage
    default:
      return false
    }
  }
}
