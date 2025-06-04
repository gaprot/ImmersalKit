//
//  MapEntryTests.swift
//  Demo
//
//  Created by ryudai.kimura on 2025/06/02.
//

import Foundation
import RealityKit
import Testing

@testable import Demo
@testable import ImmersalKit

struct MapEntryTests {

  @Test func testMapEntryInitialization() {
    let mapId: MapId = 123
    let entry = MapEntry(mapId: mapId)

    #expect(entry.mapId == mapId)
    #expect(entry.relation.position == simd_float3.zero)
    #expect(entry.relation.scale == simd_float3(1, 1, 1))
    #expect(entry.sceneParent == nil)
  }

  @Test func testMapEntryWithCustomRelation() {
    let mapId: MapId = 456
    let relation = MapToSpaceRelation(
      position: simd_float3(1, 2, 3),
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(2, 2, 2)
    )
    let entry = MapEntry(mapId: mapId, relation: relation)

    #expect(entry.mapId == mapId)
    #expect(entry.relation.position == simd_float3(1, 2, 3))
    #expect(entry.relation.scale == simd_float3(2, 2, 2))
  }

  @Test func testMapEntryTransformPoint() {
    let mapId: MapId = 123
    let relation = MapToSpaceRelation(
      position: simd_float3(10, 0, 0),
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(1, 1, 1)
    )
    let entry = MapEntry(mapId: mapId, relation: relation)

    let point = simd_float3(0, 0, 0)
    let transformedPoint = entry.transformPoint(point)

    #expect(transformedPoint == simd_float3(10, 0, 0))
  }

  @Test func testMapEntryTransformMultiplePoints() {
    let mapId: MapId = 789
    let rotation = simd_quatf(angle: .pi / 2, axis: simd_float3(0, 1, 0))
    let relation = MapToSpaceRelation(
      position: simd_float3(5, 0, 0),
      rotation: rotation,
      scale: simd_float3(2, 2, 2)
    )
    let entry = MapEntry(mapId: mapId, relation: relation)

    // 複数の点を変換
    let points = [
      simd_float3(1, 0, 0),
      simd_float3(0, 1, 0),
      simd_float3(0, 0, 1),
    ]

    let transformed = points.map { entry.transformPoint($0) }

    // スケール2倍、Y軸90度回転、(5,0,0)移動後の期待値を確認
    #expect(abs(transformed[0].x - 5.0) < 0.0001)  // (1,0,0) -> (0,0,-2) + (5,0,0)
    #expect(abs(transformed[0].z - (-2.0)) < 0.0001)

    #expect(abs(transformed[1].x - 5.0) < 0.0001)  // (0,1,0) -> (0,2,0) + (5,0,0)
    #expect(abs(transformed[1].y - 2.0) < 0.0001)
  }

  @Test func testMapEntryEquality() {
    let mapId1: MapId = 100
    let mapId2: MapId = 200

    let entry1 = MapEntry(mapId: mapId1)
    let entry2 = MapEntry(mapId: mapId1)
    let entry3 = MapEntry(mapId: mapId2)

    // 同じmapIdなら等しい
    #expect(entry1.mapId == entry2.mapId)
    // 異なるmapIdなら等しくない
    #expect(entry1.mapId != entry3.mapId)
  }

  @Test func testMapEntryWithRotation() {
    let mapId: MapId = 999
    let rotation = simd_quatf(angle: .pi / 2, axis: simd_float3(0, 1, 0))  // Y軸90度回転
    let relation = MapToSpaceRelation(
      position: simd_float3.zero,
      rotation: rotation,
      scale: simd_float3(1, 1, 1)
    )
    let entry = MapEntry(mapId: mapId, relation: relation)

    // X軸方向の単位ベクトルがZ軸負方向に回転
    let point = simd_float3(1, 0, 0)
    let transformed = entry.transformPoint(point)

    #expect(abs(transformed.x - 0.0) < 0.0001)
    #expect(abs(transformed.y - 0.0) < 0.0001)
    #expect(abs(transformed.z - (-1.0)) < 0.0001)
  }

  @Test func testMapEntryScaling() {
    let mapId: MapId = 555
    let relation = MapToSpaceRelation(
      position: simd_float3.zero,
      rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
      scale: simd_float3(3, 2, 4)
    )
    let entry = MapEntry(mapId: mapId, relation: relation)

    let point = simd_float3(1, 1, 1)
    let transformed = entry.transformPoint(point)

    #expect(transformed == simd_float3(3, 2, 4))
  }
}
