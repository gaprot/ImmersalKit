//
//  DemoTests.swift
//  DemoTests
//
//  Created by ryudai.kimura on 2025/05/27.
//

import Foundation
import RealityKit
import Testing

@testable import Demo
@testable import ImmersalKit

// MARK: - Mock URLSession Implementation

class MockURLSession: URLSessionProtocol {
  var mockData: Data?
  var mockResponse: URLResponse?
  var mockError: Error?

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    if let error = mockError {
      throw error
    }

    guard let data = mockData, let response = mockResponse else {
      throw URLError(.unknown)
    }

    return (data, response)
  }
}

// MARK: - RestClient Tests

struct DemoTests {

  @Test func testRestClientGetVersionWithMockSession() async throws {
    // Setup mock response
    let mockSession = MockURLSession()
    let mockVersionResponse = """
      {
        "error": "none",
        "version": "1.2.3"
      }
      """.data(using: .utf8)!

    let mockHTTPResponse = HTTPURLResponse(
      url: URL(string: "https://api.immersal.com/version")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!

    mockSession.mockData = mockVersionResponse
    mockSession.mockResponse = mockHTTPResponse

    // Create RestClient with mock session
    let tokenProvider = BundleTokenProvider()
    let restClient = RestClient(session: mockSession, tokenProvider: tokenProvider)

    // Test
    let version = try await restClient.getVersion()
    #expect(version == "1.2.3")
  }

  @Test func testRestClientNetworkError() async throws {
    // Setup mock to return error
    let mockSession = MockURLSession()
    mockSession.mockError = URLError(.networkConnectionLost)

    // Create RestClient with mock session
    let tokenProvider = BundleTokenProvider()
    let restClient = RestClient(session: mockSession, tokenProvider: tokenProvider)

    // Test that error is properly handled
    do {
      _ = try await restClient.getVersion()
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Check if it's an ImmersalError.networkError or the original URLError
      switch error {
      case let ImmersalError.networkError(underlyingError):
        #expect(underlyingError is URLError)
      case is URLError:
        // URLError thrown directly is also acceptable
        #expect(true)
      default:
        #expect(Bool(false), "Expected ImmersalError.networkError or URLError, got: \(error)")
      }
    }
  }

  @Test func testRestClientHTTPError() async throws {
    // Setup mock to return 404 error
    let mockSession = MockURLSession()
    let mockErrorResponse = """
      {
        "error": "Not Found"
      }
      """.data(using: .utf8)!

    let mockHTTPResponse = HTTPURLResponse(
      url: URL(string: "https://api.immersal.com/version")!,
      statusCode: 404,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!

    mockSession.mockData = mockErrorResponse
    mockSession.mockResponse = mockHTTPResponse

    // Create RestClient with mock session
    let tokenProvider = BundleTokenProvider()
    let restClient = RestClient(session: mockSession, tokenProvider: tokenProvider)

    // Test that HTTP error is properly handled
    do {
      _ = try await restClient.getVersion()
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Verify it's an ImmersalError.apiError
      if case let ImmersalError.apiError(errorMessage) = error {
        #expect(errorMessage == "Not Found")
      } else {
        #expect(Bool(false), "Expected ImmersalError.apiError, got: \(error)")
      }
    }
  }

  @Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  }

}

// MARK: - Confidence Based Alignment Controller Tests

struct ConfidenceBasedAlignmentControllerTests {

  @Test func testInitialState() {
    let controller = ConfidenceBasedAlignmentController()
    #expect(controller.latestConfidence == nil)
    #expect(controller.averageConfidence == 0.0)
    #expect(controller.getConfidenceTrend() == "insufficient_data")
  }

  @Test func testFirstLocalization() {
    let controller = ConfidenceBasedAlignmentController()
    // 初回ローカライゼーションは常に位置合わせを実行
    let shouldPerform = controller.shouldPerformAlignment(withNewConfidence: 50.0)
    #expect(shouldPerform)
    #expect(controller.latestConfidence == 50.0)
    #expect(controller.averageConfidence == 50.0)
  }

  @Test func testConfidenceIncrease() {
    let controller = ConfidenceBasedAlignmentController()
    // 信頼度が上昇した場合は位置合わせを実行
    controller.shouldPerformAlignment(withNewConfidence: 30.0)
    let shouldPerform = controller.shouldPerformAlignment(withNewConfidence: 40.0)
    #expect(shouldPerform)
  }

  @Test func testConfidenceDecrease() {
    let controller = ConfidenceBasedAlignmentController()
    // 信頼度が大幅に低下した場合は位置合わせをスキップ
    controller.shouldPerformAlignment(withNewConfidence: 50.0)
    let shouldPerform = controller.shouldPerformAlignment(withNewConfidence: 40.0)  // 10ポイント低下
    #expect(!shouldPerform)
  }

  @Test func testSmallConfidenceDecrease() {
    let controller = ConfidenceBasedAlignmentController()
    // 信頼度の低下が閾値以下の場合は位置合わせを実行
    controller.shouldPerformAlignment(withNewConfidence: 50.0)
    let shouldPerform = controller.shouldPerformAlignment(withNewConfidence: 49.0)  // 1ポイント低下（デフォルト閾値-2.0以内）
    #expect(shouldPerform)
  }

  @Test func testAbsoluteMinimumConfidence() {
    let controller = ConfidenceBasedAlignmentController()
    // 絶対的な最小信頼度以下の場合は常にスキップ（デフォルト15.0）
    let shouldPerform = controller.shouldPerformAlignment(withNewConfidence: 15.0)
    #expect(!shouldPerform)
  }

  @Test func testCustomConfiguration() {
    let controller = ConfidenceBasedAlignmentController()
    let config = ConfidenceBasedAlignmentConfiguration(
      isEnabled: true,
      minimumConfidenceDelta: -10.0,
      absoluteMinimumConfidence: 20.0,
      maxHistorySize: 3
    )
    controller.updateConfiguration(config)

    // 20以下は常にスキップ
    #expect(!controller.shouldPerformAlignment(withNewConfidence: 15.0))

    // 信頼度が10ポイント以上低下した場合のテスト
    controller.shouldPerformAlignment(withNewConfidence: 50.0)
    #expect(!controller.shouldPerformAlignment(withNewConfidence: 35.0))  // 15ポイント低下
    #expect(controller.shouldPerformAlignment(withNewConfidence: 45.0))  // 5ポイント低下
  }

  @Test func testDisabledConfiguration() {
    let controller = ConfidenceBasedAlignmentController()
    let config = ConfidenceBasedAlignmentConfiguration(isEnabled: false)
    controller.updateConfiguration(config)

    // 機能が無効な場合は常に位置合わせを実行
    #expect(controller.shouldPerformAlignment(withNewConfidence: 5.0))
    #expect(controller.shouldPerformAlignment(withNewConfidence: 100.0))
  }

  @Test func testHistoryLimit() {
    let controller = ConfidenceBasedAlignmentController()
    let config = ConfidenceBasedAlignmentConfiguration(maxHistorySize: 3)
    controller.updateConfiguration(config)

    // 履歴サイズを超える場合の動作確認
    controller.shouldPerformAlignment(withNewConfidence: 10.0)
    controller.shouldPerformAlignment(withNewConfidence: 20.0)
    controller.shouldPerformAlignment(withNewConfidence: 30.0)
    controller.shouldPerformAlignment(withNewConfidence: 40.0)

    // 最新の3つが保持されているか確認
    let status = controller.getStatusInfo()
    let history = status["confidenceHistory"] as! [Float]
    #expect(history.count == 3)
    #expect(history[0] == 40.0)  // 最新
    #expect(history[1] == 30.0)
    #expect(history[2] == 20.0)  // 最古
  }

  @Test func testClearHistory() {
    let controller = ConfidenceBasedAlignmentController()
    controller.shouldPerformAlignment(withNewConfidence: 30.0)
    controller.shouldPerformAlignment(withNewConfidence: 40.0)

    #expect(controller.latestConfidence != nil)

    controller.clearHistory()

    #expect(controller.latestConfidence == nil)
    #expect(controller.averageConfidence == 0.0)
  }

  @Test func testIncreasingTrend() {
    let controller = ConfidenceBasedAlignmentController()
    controller.shouldPerformAlignment(withNewConfidence: 10.0)
    controller.shouldPerformAlignment(withNewConfidence: 20.0)
    controller.shouldPerformAlignment(withNewConfidence: 30.0)

    #expect(controller.getConfidenceTrend() == "increasing")
  }

  @Test func testDecreasingTrend() {
    let controller = ConfidenceBasedAlignmentController()
    controller.shouldPerformAlignment(withNewConfidence: 30.0)
    controller.shouldPerformAlignment(withNewConfidence: 20.0)
    controller.shouldPerformAlignment(withNewConfidence: 10.0)

    #expect(controller.getConfidenceTrend() == "decreasing")
  }

  @Test func testStableTrend() {
    let controller = ConfidenceBasedAlignmentController()
    controller.shouldPerformAlignment(withNewConfidence: 20.0)
    controller.shouldPerformAlignment(withNewConfidence: 20.0)
    controller.shouldPerformAlignment(withNewConfidence: 20.0)

    #expect(controller.getConfidenceTrend() == "stable")
  }

  @Test func testStatusInfo() {
    let controller = ConfidenceBasedAlignmentController()
    controller.shouldPerformAlignment(withNewConfidence: 25.0)
    controller.shouldPerformAlignment(withNewConfidence: 35.0)

    let status = controller.getStatusInfo()

    #expect(status["isEnabled"] as! Bool == true)
    #expect(status["latestConfidence"] as! Float == 35.0)
    #expect(status["averageConfidence"] as! Float == 30.0)
    #expect(status["historyCount"] as! Int == 2)
    #expect(status["minimumConfidenceDelta"] as! Float == -2.0)
    #expect(status["absoluteMinimumConfidence"] as! Float == 15.0)
  }

  @Test func testNegativeConfidenceValues() {
    let controller = ConfidenceBasedAlignmentController()
    // 負の信頼度値でも正常に動作することを確認
    #expect(!controller.shouldPerformAlignment(withNewConfidence: -10.0))
  }

  @Test func testVeryHighConfidenceValues() {
    let controller = ConfidenceBasedAlignmentController()
    // 非常に高い信頼度値でも正常に動作することを確認
    #expect(controller.shouldPerformAlignment(withNewConfidence: 1000.0))
  }

  @Test func testZeroConfidence() {
    let controller = ConfidenceBasedAlignmentController()
    // 信頼度0でも正常に動作することを確認
    #expect(!controller.shouldPerformAlignment(withNewConfidence: 0.0))
  }

  // 追加テスト: 境界値テスト
  @Test func testBoundaryConfidenceValues() {
    let controller = ConfidenceBasedAlignmentController()

    // デフォルトの最小信頼度(15.0)の境界値テスト
    #expect(!controller.shouldPerformAlignment(withNewConfidence: 14.9))
    #expect(!controller.shouldPerformAlignment(withNewConfidence: 15.0))
    #expect(controller.shouldPerformAlignment(withNewConfidence: 15.1))
  }

  // 追加テスト: 連続した同じ値での動作
  @Test func testConsecutiveSameValues() {
    let controller = ConfidenceBasedAlignmentController()

    // 初回は常に実行
    #expect(controller.shouldPerformAlignment(withNewConfidence: 50.0))
    // 同じ値の場合も実行（低下していないため）
    #expect(controller.shouldPerformAlignment(withNewConfidence: 50.0))
    #expect(controller.shouldPerformAlignment(withNewConfidence: 50.0))
  }

  // 追加テスト: 急激な変動パターン
  @Test func testRapidFluctuations() {
    let controller = ConfidenceBasedAlignmentController()

    controller.shouldPerformAlignment(withNewConfidence: 30.0)
    controller.shouldPerformAlignment(withNewConfidence: 80.0)  // 大幅上昇
    #expect(!controller.shouldPerformAlignment(withNewConfidence: 20.0))  // 大幅低下
    #expect(controller.shouldPerformAlignment(withNewConfidence: 90.0))  // 大幅上昇
  }
}

struct SimdExtensionTests {

  @Test func testSimdFloat4x4InitWithPositionRotation() {
    let position = simd_float3(1, 2, 3)
    let rotation = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))

    let matrix = simd_float4x4(position: position, rotation: rotation)

    // 位置成分の確認
    #expect(matrix.columns.3.x == 1.0)
    #expect(matrix.columns.3.y == 2.0)
    #expect(matrix.columns.3.z == 3.0)
    #expect(matrix.columns.3.w == 1.0)

    // 回転なし（恒等回転）の確認
    #expect(matrix.columns.0.x == 1.0)
    #expect(matrix.columns.1.y == 1.0)
    #expect(matrix.columns.2.z == 1.0)
  }

  @Test func testSimdFloat4x4InitWithRotation() {
    let position = simd_float3(0, 0, 0)
    let rotation = simd_quatf(angle: .pi / 2, axis: simd_float3(0, 1, 0))  // Y軸90度回転

    let matrix = simd_float4x4(position: position, rotation: rotation)

    // 90度Y軸回転の確認（右手系）
    // X軸ベクトル(1,0,0)がZ軸正方向(0,0,1)になる
    #expect(abs(matrix.columns.0.x - 0.0) < 0.0001)
    #expect(abs(matrix.columns.0.z - (-1.0)) < 0.0001)

    // Z軸ベクトル(0,0,1)がX軸負方向(-1,0,0)になる
    #expect(abs(matrix.columns.2.x - 1.0) < 0.0001)
    #expect(abs(matrix.columns.2.z - 0.0) < 0.0001)
  }
}

// MARK: - Error Type Tests

struct ErrorTypeTests {

  @Test func testImmersalErrorEquality() {
    let error1 = ImmersalError.missingToken
    let error2 = ImmersalError.missingToken
    let error3 = ImmersalError.invalidURL

    // 同じエラータイプは等しい
    #expect(error1 == error2)
    // 異なるエラータイプは等しくない
    #expect(error1 != error3)
  }

  @Test func testImmersalErrorDescriptions() {
    // 各エラータイプが適切な説明を持つことを確認
    #expect(ImmersalError.missingToken.errorDescription != nil)
    #expect(ImmersalError.invalidURL.errorDescription != nil)
    #expect(ImmersalError.noData.errorDescription != nil)

    // エラー説明が空でないことを確認
    #expect(!ImmersalError.missingToken.errorDescription!.isEmpty)
    #expect(!ImmersalError.invalidURL.errorDescription!.isEmpty)
    #expect(!ImmersalError.noData.errorDescription!.isEmpty)
  }

  @Test func testImmersalErrorRecoverySuggestions() {
    // 各エラータイプがリカバリ提案を持つことを確認
    #expect(ImmersalError.missingToken.recoverySuggestion != nil)
    #expect(ImmersalError.networkError(URLError(.timedOut)).recoverySuggestion != nil)
    #expect(ImmersalError.httpError(404).recoverySuggestion != nil)
  }

  @Test func testImmersalErrorHTTPCodes() {
    // HTTPエラーコードが正しく保存されることを確認
    let error404 = ImmersalError.httpError(404)
    let error500 = ImmersalError.httpError(500)

    #expect(error404 != error500)

    if case .httpError(let code) = error404 {
      #expect(code == 404)
    } else {
      #expect(Bool(false), "Should be httpError case")
    }
  }

  @Test func testImmersalErrorAPIMessages() {
    // APIエラーメッセージが正しく保存されることを確認
    let error1 = ImmersalError.apiError("Invalid map ID")
    let error2 = ImmersalError.apiError("Server unavailable")

    #expect(error1 != error2)

    if case .apiError(let message) = error1 {
      #expect(message == "Invalid map ID")
    } else {
      #expect(Bool(false), "Should be apiError case")
    }
  }
}
