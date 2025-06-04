//
//  MapToSpaceRelationTests.swift
//  Demo
//
//  Created by ryudai.kimura on 2025/06/02.
//

import Foundation
import RealityKit
import Testing

@testable import Demo
@testable import ImmersalKit

struct MapToSpaceRelationTests {

  @Test func testMapToSpaceRelationInitialization() {
    let relation = MapToSpaceRelation()

    #expect(relation.position == simd_float3.zero)
    #expect(relation.rotation.real == 1.0)
    #expect(relation.scale == simd_float3(1, 1, 1))
  }

  @Test func testMapToSpaceRelationWithParameters() {
    let relation = MapToSpaceRelation(
      position: simd_float3(1, 2, 3),
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(2, 2, 2)
    )

    #expect(relation.position == simd_float3(1, 2, 3))
    #expect(relation.rotation.real == 1.0)
    #expect(relation.scale == simd_float3(2, 2, 2))
  }

  @Test func testTransformationMatrix() {
    let relation = MapToSpaceRelation(
      position: simd_float3(1, 2, 3),
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(2, 2, 2)
    )

    let matrix = relation.matrix()

    // Check translation components
    #expect(matrix.columns.3.x == 1.0)
    #expect(matrix.columns.3.y == 2.0)
    #expect(matrix.columns.3.z == 3.0)
  }

  @Test func testTransformPoint() {
    let relation = MapToSpaceRelation(
      position: simd_float3(10, 0, 0),
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(2, 2, 2)
    )

    let point = simd_float3(1, 1, 1)
    let transformedPoint = relation.transformPoint(point)

    // スケール2倍 + 位置(10,0,0)移動
    #expect(transformedPoint == simd_float3(12, 2, 2))
  }

  @Test func testInverseTransformPoint() {
    let relation = MapToSpaceRelation(
      position: simd_float3(10, 0, 0),
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(2, 2, 2)
    )

    let worldPoint = simd_float3(12, 2, 2)
    let mapPoint = relation.inverseTransformPoint(worldPoint)

    // 逆変換で元の点に戻る
    #expect(abs(mapPoint.x - 1.0) < 0.0001)
    #expect(abs(mapPoint.y - 1.0) < 0.0001)
    #expect(abs(mapPoint.z - 1.0) < 0.0001)
  }

  @Test func testRotationTransform() {
    // 90度Y軸回転
    let rotation = simd_quatf(angle: .pi / 2, axis: simd_float3(0, 1, 0))
    let relation = MapToSpaceRelation(
      position: simd_float3.zero,
      rotation: rotation,
      scale: simd_float3(1, 1, 1)
    )

    let point = simd_float3(1, 0, 0)
    let transformedPoint = relation.transformPoint(point)

    // X軸正方向の点がZ軸負方向に回転
    #expect(abs(transformedPoint.x - 0.0) < 0.0001)
    #expect(abs(transformedPoint.y - 0.0) < 0.0001)
    #expect(abs(transformedPoint.z - (-1.0)) < 0.0001)
  }

  @Test func testComplexTransform() {
    // 複合変換：スケール、回転、移動
    let rotation = simd_quatf(angle: .pi / 4, axis: simd_float3(0, 1, 0))
    let relation = MapToSpaceRelation(
      position: simd_float3(5, 10, 15),
      rotation: rotation,
      scale: simd_float3(2, 3, 4)
    )

    // 原点での変換
    let origin = simd_float3.zero
    let transformedOrigin = relation.transformPoint(origin)
    #expect(transformedOrigin == simd_float3(5, 10, 15))

    // 逆変換で元に戻ることを確認
    let inverted = relation.inverseTransformPoint(transformedOrigin)
    #expect(abs(inverted.x) < 0.0001)
    #expect(abs(inverted.y) < 0.0001)
    #expect(abs(inverted.z) < 0.0001)
  }

  @Test func testIdentityTransform() {
    let relation = MapToSpaceRelation()
    let point = simd_float3(1, 2, 3)
    let transformed = relation.transformPoint(point)

    // 恒等変換では点は変わらない
    #expect(transformed == point)
  }

  @Test func testMatrixInverse() {
    let relation = MapToSpaceRelation(
      position: simd_float3(1, 2, 3),
      rotation: simd_quatf(angle: .pi / 6, axis: simd_float3(1, 0, 0)),
      scale: simd_float3(2, 2, 2)
    )

    let matrix = relation.matrix()
    let inverse = relation.inverseMatrix()
    let identity = matrix * inverse

    // 行列とその逆行列の積は単位行列になる
    let tolerance: Float = 0.0001
    for i in 0..<4 {
      for j in 0..<4 {
        let expected: Float = (i == j) ? 1.0 : 0.0
        #expect(abs(identity[i][j] - expected) < tolerance)
      }
    }
  }

  @Test func testNonUniformScale() {
    let relation = MapToSpaceRelation(
      position: simd_float3.zero,
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(2, 4, 8)
    )

    let point = simd_float3(1, 1, 1)
    let transformed = relation.transformPoint(point)

    #expect(transformed == simd_float3(2, 4, 8))
  }

  @Test func testChainedTransformations() {
    let relation1 = MapToSpaceRelation(
      position: simd_float3(1, 0, 0),
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(2, 2, 2)
    )

    let relation2 = MapToSpaceRelation(
      position: simd_float3(0, 1, 0),
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(0.5, 0.5, 0.5)
    )

    let point = simd_float3(1, 1, 1)

    // relation1で変換後、その結果をrelation2で変換
    let intermediate = relation1.transformPoint(point)
    let final = relation2.transformPoint(intermediate)

    // 期待値: (1,1,1) -> scale 2x -> (2,2,2) -> +offset -> (3,2,2) -> scale 0.5x -> (1.5,1,1) -> +offset -> (1.5,2,1)
    #expect(abs(final.x - 1.5) < 0.0001)
    #expect(abs(final.y - 2.0) < 0.0001)
    #expect(abs(final.z - 1.0) < 0.0001)
  }
}
