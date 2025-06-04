//
//  Logger+Extensions.swift
//  ImmersalKit
//
//  Created by ryudai.kimura on 2025/06/02.
//

import Foundation
import os.log

extension Logger {
  /// Shared logger for ImmersalKit
  static let immersalKit = Logger(subsystem: "com.yourcompany.immersalkit", category: "ImmersalKit")

  /// Session-specific logger
  static let session = Logger(subsystem: "com.yourcompany.immersalkit", category: "Session")

  /// Localization-specific logger
  static let localization = Logger(
    subsystem: "com.yourcompany.immersalkit", category: "Localization")

  /// Map management logger
  static let mapManagement = Logger(
    subsystem: "com.yourcompany.immersalkit", category: "MapManagement")

  /// Network operations logger
  static let network = Logger(subsystem: "com.yourcompany.immersalkit", category: "Network")

  /// Error reporting logger
  static let error = Logger(subsystem: "com.yourcompany.immersalkit", category: "Error")
}
