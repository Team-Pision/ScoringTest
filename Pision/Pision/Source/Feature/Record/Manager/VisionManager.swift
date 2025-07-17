//
//  VisionManager.swift
//  PisionTest1
//
//  Created by 여성일 on 7/9/25.
//

import Vision
import Foundation

/// VisionManager
/// - 역할: 카메라 프레임에서 얼굴 및 신체를 감지하고, EAR(눈 감김 정도), 깜빡임, Yaw, Roll 등의 정보를 계산 및 전달합니다.
/// - 사용 기술: Apple Vision 프레임워크
///
/// 기능 개요:
/// 1. 얼굴 랜드마크 분석 (VNDetectFaceLandmarksRequest)
///     - yaw(고개 좌우 회전), roll(고개 기울기) 추출
///     - EAR(눈 감김 비율) 계산
///     - 깜빡임 여부 및 횟수 추적
///
/// 2. 신체 자세 분석 (VNDetectHumanBodyPoseRequest)
///     - 포즈 데이터를 추출하여 MLManager에 전달
///
/// 3. MLManager 연동
///     - 포즈 기반 졸음 감지 모델 예측값(label, confidence)을 수신하고 외부로 전달
///
/// 외부 연동 클로저:
/// - onFaceDetection: 얼굴 감지 결과 및 yaw, roll 정보 전달
/// - onPoseDetection: 신체 포즈 정보 전달
/// - onBlinkDetection: EAR 값, 깜빡임 여부, 누적 깜빡임 횟수 전달
/// - onMLPrediction: ML 모델 예측 결과(label, confidence) 전달
///
/// 기타:
/// - blinkCount는 `resetBlinkCount()`를 통해 수동 초기화 가능

class VisionManager {
  // 기존 클로저들
  var onFaceDetection: (([VNFaceObservation], [Double], [Double]) -> Void)?
  var onPoseDetection: ((VNHumanBodyPoseObservation) -> Void)?
  
  // 새로 추가할 클로저 - EAR, 깜빡임여부, 깜빡임횟수
  var onBlinkDetection: ((Float, Bool, Int) -> Void)?
  
  // MLManager 연동을 위한 클로저
  var onMLPrediction: ((String, Double) -> Void)?
  
  // 깜빡임 추적용 변수들
  private var lastBlinkTime = Date()
  private var blinkCount = 0
  private var lastEARState = false // 마지막 깜빡임 상태
  
  // MLManager 인스턴스
  private var mlManager: MLManager?
  
  init() {
    // MLManager 초기화
    mlManager = MLManager()
    setupMLManager()
  }
  
  private func setupMLManager() {
    mlManager?.onPrediction = { [weak self] label, confidence in
      DispatchQueue.main.async {
        self?.onMLPrediction?(label, confidence)
      }
    }
  }
  
  func processFaceLandMark(pixelBuffer: CVPixelBuffer) {
    let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
      guard let results = request.results as? [VNFaceObservation] else { return }
      
      var yaws: [Double] = []
      var rolls: [Double] = []
      
      for face in results {
        if let yaw = face.yaw {
          yaws.append(yaw.doubleValue)
        }
        if let roll = face.roll {
          rolls.append(roll.doubleValue)
        }
        
        // EAR 계산 및 깜빡임 감지
        if let landmarks = face.landmarks,
           let leftEye = landmarks.leftEye,
           let rightEye = landmarks.rightEye {
          
          let leftEAR = self?.calculateEAR(eye: leftEye) ?? 0
          let rightEAR = self?.calculateEAR(eye: rightEye) ?? 0
          let avgEAR = (leftEAR + rightEAR) / 2.0
          
          self?.processBlinkDetection(ear: avgEAR)
        }
      }
      
      // 기존 콜백 호출
      self?.onFaceDetection?(results, yaws, rolls)
    }
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
    try? handler.perform([request])
  }
  
  func processBodyPose(pixelBuffer: CVPixelBuffer) {
    let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
      guard let results = request.results as? [VNHumanBodyPoseObservation],
            let observation = results.first else { return }
      
      // MLManager에 포즈 데이터 전달
      self?.mlManager?.addPoseObservation(from: observation)
      
      // 기존 콜백도 유지
      self?.onPoseDetection?(observation)
    }
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
    try? handler.perform([request])
  }
  
  // MARK: - EAR 및 깜빡임 감지 메서드들
  
  private func calculateEAR(eye: VNFaceLandmarkRegion2D) -> Float {
    let points = eye.normalizedPoints
    guard points.count >= 6 else { return 0.25 }
    
    // EAR 계산: (수직 거리 평균) / (수평 거리)
    // 눈의 랜드마크 포인트 인덱스는 Vision 프레임워크 기준
    let p1 = points[1]  // 상단 좌측
    let p2 = points[2]  // 상단 우측
    let p4 = points[4]  // 하단 우측
    let p5 = points[5]  // 하단 좌측
    let p0 = points[0]  // 좌측 끝
    let p3 = points[3]  // 우측 끝
    
    let verticalDist1 = abs(p1.y - p5.y)
    let verticalDist2 = abs(p2.y - p4.y)
    let horizontalDist = abs(p0.x - p3.x)
    
    guard horizontalDist > 0 else { return 0.25 }
    
    let ear = (verticalDist1 + verticalDist2) / (2.0 * horizontalDist)
    return Float(ear)
  }
  
  private func processBlinkDetection(ear: Float) {
    let isBlinking = ear < 0.2
    let currentTime = Date()
    
    // 깜빡임 상태 변화 감지
    if !lastEARState && isBlinking {
      // 깜빡임 시작
      lastEARState = true
    } else if lastEARState && !isBlinking {
      // 깜빡임 끝 - 깜빡임 카운트 증가
      if currentTime.timeIntervalSince(lastBlinkTime) > 0.3 {
        blinkCount += 1
        lastBlinkTime = currentTime
        
        // 깜빡임 감지 콜백 호출
        DispatchQueue.main.async {
          self.onBlinkDetection?(ear, true, self.blinkCount)
        }
      }
      lastEARState = false
    } else {
      // 깜빡임이 아닌 경우에도 EAR 값 전달
      DispatchQueue.main.async {
        self.onBlinkDetection?(ear, false, self.blinkCount)
      }
    }
  }
  
  // 깜빡임 카운트 리셋 (필요시 사용)
  func resetBlinkCount() {
    blinkCount = 0
  }
}
