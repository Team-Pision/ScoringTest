//
//  CameraManager.swift
//  PisionTest1
//
//  Created by 여성일 on 7/9/25.
//

import AVFoundation
import SwiftUI
import Vision

final class CameraManager: NSObject, ObservableObject {
  let session = AVCaptureSession()
  
  private let videoOutput = AVCaptureVideoDataOutput()
  private var isSeesionConfigured = false
  private let sessionQueue = DispatchQueue(label: "CameraSessionQueue")
  
  let visionManager = VisionManager() // private 제거
  
  /*
   Vision 처리 결과를 외부로 넘겨주기 위한 클로저
   Vision 처리 값을 외부 객체나 ViewModel에서 사용할 수 있도록 전달합니다
   */
  var onYawsUpdate: (([Double]) -> Void)?
  var onRollsUpdate: (([Double]) -> Void)?
  var onPoseUpdate: ((VNHumanBodyPoseObservation) -> Void)?
  
  override init() {
    super.init()
    
    // 비전매니저에서 비전 분석 결과를 클로저로 받아와서 처리 결과를 클로저로 외부(여기서는 뷰모델에 전달할거임)에 전달
    // 각 클로저는 ViewModel에서 처리함
    visionManager.onFaceDetection = { [weak self] _, yaws, rolls in
      DispatchQueue.main.async {
        self?.onYawsUpdate?(yaws)
        self?.onRollsUpdate?(rolls)
      }
    }
    
    visionManager.onPoseDetection = { [weak self] observation in
      DispatchQueue.main.async {
        self?.onPoseUpdate?(observation)
      }
    }
  }
  
  func startSession() {
    sessionQueue.async {
      if !self.session.isRunning {
        self.session.startRunning()
      }
    }
  }
  
  func stopSession() {
    sessionQueue.async {
      if self.session.isRunning {
        self.session.stopRunning()
      }
    }
  }
  
  func requestAndCheckPermissions() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        if granted {
          self?.configureSessionIfNeeded()
        } else {
          print("사용자가 카메라 접근을 거부했습니다.")
        }
      }
      
    case .authorized:
      configureSessionIfNeeded()
      
    case .restricted, .denied:
      print("카메라 접근이 제한되었거나 거부됨")
      
    @unknown default:
      print("알 수 없는 권한 상태")
    }
  }
}

extension CameraManager {
  private func configureSession() {
    session.beginConfiguration()
    session.sessionPreset = .high
    
    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera ,for: .video, position: .front),
          let input = try? AVCaptureDeviceInput(device: device),
          session.canAddInput(input) else {
      print("Log: 카메라 인풋 설정 실패")
      session.commitConfiguration()
      return
    }
    session.addInput(input)
    
    if session.canAddOutput(videoOutput) {
      videoOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
      ]
      videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
      videoOutput.alwaysDiscardsLateVideoFrames = true
      session.addOutput(videoOutput)
      
      if #available(iOS 17.0, *) {
        videoOutput.connections.first?.videoRotationAngle = 0
      } else {
        videoOutput.connections.first?.videoOrientation = .portrait
      }
      
      session.commitConfiguration()
    }
    
    session.commitConfiguration()
  }
  
  private func configureSessionIfNeeded() {
    guard !isSeesionConfigured else {
      print("이미 세션이 구성되어 있음")
      return
    }
    isSeesionConfigured = true
    configureSession()
  }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    visionManager.processFaceLandMark(pixelBuffer: pixelBuffer)
    visionManager.processBodyPose(pixelBuffer: pixelBuffer)
  }
}
