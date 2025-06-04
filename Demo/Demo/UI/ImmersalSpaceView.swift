import ImmersalKit
import RealityKit
import RealityKitContent
import SwiftUI

/// DEMO: This view demonstrates how to use RealityView Attachments to add SwiftUI elements
/// to specific 3D locations within RealityKit content.
///
/// Key concepts shown:
/// 1. Creating attachment points at map origins (red spheres with "Origin" labels)
/// 2. Adding UI below existing entities (blue spheres with info panels)
/// 3. Dynamic attachment updates based on localization state
struct ImmersalSpaceView: View {
  @State private var isLocalizing = false
  @State private var attachmentEntities: [String: Entity] = [:]
  @State private var mapInfos: [Int: MapInfo] = [:]
  @State private var dynamicAnnotations: [DynamicAnnotation] = []
  @State private var rootEntity: Entity?

  let immersalKit: ImmersalKit

  struct MapInfo {
    let mapId: Int
    var position: SIMD3<Float>
    var isLocalized: Bool
    var confidence: Float?
  }

  struct DynamicAnnotation: Identifiable {
    let id = UUID().uuidString
    let title: String
    let position: SIMD3<Float>
    let createdAt = Date()
    var entity: Entity?
  }

  var body: some View {
    RealityView { content, attachments in
      let root = Entity()
      content.add(root)
      self.rootEntity = root

      // Register ImmersalMap set up on RealityKitContent
      if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
        content.add(scene)

        // Register maps and setup attachments
        scene.forEachDescendant(withComponent: RealityKitContent.ImmersalMapComponent.self) {
          mapEntity, mapComponent in
          print("Registering map \(mapComponent.mapId) with entity: \(mapEntity.name)")
          let result = immersalKit.mapManager.registerMap(
            mapEntity: mapEntity, mapId: mapComponent.mapId)

          // Initialize map info for UI updates
          mapInfos[mapComponent.mapId] = MapInfo(
            mapId: mapComponent.mapId,
            position: mapEntity.position(relativeTo: nil),
            isLocalized: false,
            confidence: nil
          )

          // DEMO: Create attachment point at map origin
          // This shows how to add UI elements at specific 3D locations
          let mapOriginId = "origin_\(mapComponent.mapId)"
          let originEntity = Entity()
          originEntity.position = [0, 0, 0]  // Map origin
          mapEntity.addChild(originEntity)
          attachmentEntities[mapOriginId] = originEntity

          // DEMO: Add visual marker below the attachment UI
          let originMarker = ModelEntity(
            mesh: MeshResource.generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .red, isMetallic: false)]
          )
          originMarker.position = [0, -0.1, 0]  // 10cm below attachment UI
          originEntity.addChild(originMarker)

          // DEMO: If there's a Sphere entity, create another attachment point below it
          mapEntity.children.forEach { entity in
            if entity.name == "Sphere" {

              // Create attachment point 10cm below the sphere
              let sphereAttachmentId = "sphere_\(mapComponent.mapId)"
              let sphereAttachmentEntity = Entity()
              sphereAttachmentEntity.position = [0, -0.1, 0]  // 10cm below sphere
              entity.addChild(sphereAttachmentEntity)
              attachmentEntities[sphereAttachmentId] = sphereAttachmentEntity

              // DEMO: Add visual marker below the attachment UI
              let sphereMarker = ModelEntity(
                mesh: MeshResource.generateSphere(radius: 0.03),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
              )
              sphereMarker.position = [0, -0.1, 0]  // Another 10cm below attachment
              sphereAttachmentEntity.addChild(sphereMarker)
            }
          }
        }
      }
    } update: { content, attachments in
      // Update attachments for each map
      for (mapId, _) in mapInfos {
        // Update origin attachment
        let originId = "origin_\(mapId)"
        if let originEntity = attachmentEntities[originId],
          let attachment = attachments.entity(for: originId)
        {
          attachment.removeFromParent()
          originEntity.addChild(attachment)
        }

        // Update sphere attachment
        let sphereId = "sphere_\(mapId)"
        if let sphereEntity = attachmentEntities[sphereId],
          let attachment = attachments.entity(for: sphereId)
        {
          attachment.removeFromParent()
          sphereEntity.addChild(attachment)
        }
      }

      // Update dynamic annotation attachments
      for annotation in dynamicAnnotations {
        if let entity = annotation.entity,
          let attachment = attachments.entity(for: "dynamic_\(annotation.id)")
        {
          entity.removeFromParent()
          entity.addChild(attachment)
          rootEntity?.addChild(entity)
        }
      }
    } attachments: {
      // DEMO: Create SwiftUI attachments for map origins
      ForEach(Array(mapInfos.keys), id: \.self) { mapId in
        Attachment(id: "origin_\(mapId)") {
          ARLabelView(
            text: "Origin \(mapId)",
            icon: "target",
            color: .red
          )
        }
      }

      // DEMO: Create info panels below Sphere entities (if found)
      ForEach(Array(mapInfos.keys), id: \.self) { mapId in
        if let info = mapInfos[mapId], attachmentEntities["sphere_\(mapId)"] != nil {
          Attachment(id: "sphere_\(mapId)") {
            ARInfoPanel(
              mapId: mapId,
              position: info.position,
              confidence: info.confidence,
              isLocalized: info.isLocalized
            )
          }
        }
      }

      // Dynamic annotation attachments
      ForEach(dynamicAnnotations) { annotation in
        Attachment(id: "dynamic_\(annotation.id)") {
          DynamicARAnnotation(
            id: annotation.id,
            title: annotation.title,
            createdAt: annotation.createdAt,
            onDelete: {
              removeAnnotation(annotation.id)
            }
          )
        }
      }

      // Coordinate display for selected annotations
      ForEach(dynamicAnnotations.filter { $0.entity != nil }) { annotation in
        Attachment(id: "coord_\(annotation.id)") {
          ARCoordinateDisplay(
            position: annotation.position,
            rotation: annotation.entity?.orientation(relativeTo: nil) ?? simd_quatf()
          )
        }
      }
    }
    .task {
      for await event in immersalKit.localizationEvents() {
        handleLocalizationEvent(event)
      }
    }
    .task {
      for await event in immersalKit.mapManager.mapEventStream() {
        handleMapEvent(event)
      }
    }
  }

  private func resetMapPosition(mapId: Int) {
    _ = immersalKit.mapManager.setMapRelation(
      mapId: mapId,
      position: .zero,
      rotation: simd_quatf(angle: 0, axis: [0, 1, 0])
    )
  }

  private func offsetMapPosition(mapId: Int) {
    _ = immersalKit.mapManager.setMapRelation(
      mapId: mapId,
      position: simd_float3(0.5, 0.2, -0.3),
      rotation: simd_quatf(angle: .pi / 6, axis: [0, 1, 0])
    )
  }

  // Handle localization events
  private func handleLocalizationEvent(_ event: LocalizationEvent) {
    switch event {
    case .started:
      break

    case .result(let result):
      Task {
        // Update map info based on localization result
        if var info = mapInfos[result.mapId] {
          info.isLocalized = true
          info.confidence = result.confidence
          info.position = result.position
          mapInfos[result.mapId] = info
        }

        // Show the map on successful localization
        if let entry = immersalKit.mapManager.mapEntries[result.mapId] {
          await MainActor.run {
            entry.sceneParent?.isEnabled = true
          }
        }
      }

    case .failed(_):
      break

    case .stopped:
      // Reset localization states
      for mapId in mapInfos.keys {
        if var info = mapInfos[mapId] {
          info.isLocalized = false
          info.confidence = nil
          mapInfos[mapId] = info
        }
      }
      break
    }
  }

  // Highlight a specific map
  private func highlightMap(_ mapId: Int) {
    guard let mapEntry = immersalKit.mapManager.mapEntries[mapId],
      let sceneParent = mapEntry.sceneParent
    else { return }

    // Create highlight effect
    Task {
      // Add a pulsing animation or highlight material
      if let modelEntity = sceneParent.findEntity(named: "_\(mapId)_*") as? ModelEntity {
        // Store original materials
        let originalMaterials = modelEntity.model?.materials ?? []

        // Apply highlight material
        var highlightMaterial = SimpleMaterial()
        highlightMaterial.color = .init(tint: .yellow.withAlphaComponent(0.5))
        highlightMaterial.metallic = 0.8
        highlightMaterial.roughness = 0.2

        if var model = modelEntity.model {
          model.materials = [highlightMaterial]
          modelEntity.model = model
        }

        // Animate scale for emphasis
        let originalScale = modelEntity.scale
        modelEntity.scale = originalScale * 1.2

        // Reset after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        modelEntity.scale = originalScale
        if var model = modelEntity.model {
          model.materials = originalMaterials
          modelEntity.model = model
        }
      }
    }
  }

  private func handleMapEvent(_ event: MapManagementEvent) {
    switch event {
    case .registered(let mapId):
      // Maps are initially hidden until loaded
      if let entry = immersalKit.mapManager.mapEntries[mapId] {
        entry.sceneParent?.isEnabled = false
      }

    case .loaded(let mapId):
      // Maps are now shown only after successful localization
      break

    case .unloaded(let mapId):
      // Hide the map when unloaded
      if let entry = immersalKit.mapManager.mapEntries[mapId] {
        entry.sceneParent?.isEnabled = false
      }

    case .error:
      break
    }
  }

  // Create annotation at tapped location
  private func createAnnotationAtLocation(_ tappedEntity: Entity?, worldPosition: SIMD3<Float>) {
    let annotationEntity = Entity()
    annotationEntity.position = worldPosition

    // Add a small sphere as visual indicator
    let mesh = MeshResource.generateSphere(radius: 0.02)
    var material = SimpleMaterial()
    material.color = .init(tint: .orange)
    let modelEntity = ModelEntity(mesh: mesh, materials: [material])
    annotationEntity.addChild(modelEntity)

    let annotation = DynamicAnnotation(
      title: "Annotation \(dynamicAnnotations.count + 1)",
      position: worldPosition,
      entity: annotationEntity
    )

    dynamicAnnotations.append(annotation)
  }

  // Remove annotation
  private func removeAnnotation(_ id: String) {
    if let index = dynamicAnnotations.firstIndex(where: { $0.id == id }) {
      let annotation = dynamicAnnotations[index]
      annotation.entity?.removeFromParent()
      dynamicAnnotations.remove(at: index)
    }
  }
}
