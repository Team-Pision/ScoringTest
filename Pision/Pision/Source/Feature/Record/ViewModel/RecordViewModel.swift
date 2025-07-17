//
//  MainViewModel.swift
//  PisionTest2
//
//  Created by 여성일 on 7/13/25.
//

import SwiftUI
import AVFoundation
import Vision

final class RecordViewModel: ObservableObject {
  @Published var yawAngles: [Double] = []
  @Published var rollAngles: [Double] = []
  @Published var predictedLabel: String = "-"
  @Published var predictionConfidence: Double = 0.0
  
  // 원래는 옵셔널 바인딩 해야합니다~ 프로토타입이니까 강제언래핑 합니다
  private let mlManager = MLManager()!
  private let cameraManager = CameraManager()
  
  var session: AVCaptureSession {
    cameraManager.session
  }
  
  init() {
    cameraManager.requestAndCheckPermissions()
    
    cameraManager.onYawsUpdate = { [weak self] yaws in
      self?.yawAngles = yaws
    }
    
    cameraManager.onRollsUpdate = { [weak self] rolls in
      self?.rollAngles = rolls
    }
    
    cameraManager.onPoseUpdate = { [weak self] pose in
      self?.mlManager.addPoseObservation(from: pose)
    }
    
    mlManager.onPrediction = { [weak self] label, confidence in
      self?.predictedLabel = label
      self?.predictionConfidence = confidence
    }
  }
  
  func start() {
    cameraManager.startSession()
  }
  
  func stop() {
    cameraManager.stopSession()
  }
}
