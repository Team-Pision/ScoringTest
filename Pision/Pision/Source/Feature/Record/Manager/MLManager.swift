//
//  MLManager.swift
//  PisionTest2
//
//  Created by 여성일 on 7/13/25.
//

import CoreML
import Vision

final class MLManager {
  private let model: pisionModel 
  private var poseBuffer: [VNHumanBodyPoseObservation] = []
  
  /*
   모델 예측 결과를 외부로 넘겨주기 위한 콜백 클로저
   예측 결과를 다른 객체나 ViewModel에서 사용할 수 있도록 전달합니다
   */
  var onPrediction: ((String, Double) -> Void)?
  
  // 생성자가 옵셔널인 이유는, 모델 load가 실패할 수 있기 때문
  // ML매니저 인스턴스 생성해서 사용할 때 프로토타입이기 때문에 강제로 언래핑해서 사용합니다.
  // 원래는 안전하게 옵셔널 바인딩 해야합니다 ~
  init?() {
    guard let loaded = try? pisionModel(configuration: MLModelConfiguration()) else {
      print("Log: 모델 로드 실패")
      return nil
    }
    self.model = loaded
  }

  /*
   우리 모델은 float32 [30, 3, 18]
   30fps / 3개의 좌표축 (x, y, confidence) / 18개의 관절
   */
  
  // 모델 input값에 맞게 시퀀스 처리하는 메소드
  func addPoseObservation(from observarion: VNHumanBodyPoseObservation) {
    poseBuffer.append(observarion)
    
    if poseBuffer.count > 30 {
      poseBuffer.removeFirst()
    }
    
    guard poseBuffer.count == 30 else { return } // 버퍼 30개 일 때만 예측 처리
    
    bodyPosePredict()
  }
  
  // 예측 메소드
  func bodyPosePredict() {
    do {
      // 모델에 맞는 인풋값 array 위에서 설명 했듯이, 우리 모델은 float32 타입의 [30, 3, 18] Array를 인풋 값으로 가짐
      let array = try MLMultiArray(shape: [30, 3, 18] as [NSNumber], dataType: .float32)
      
      // 18개의 관절 배열
      let jointNames: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
        .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
        .leftWrist, .rightWrist, .leftHip, .rightHip,
        .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
        .root
      ]
      
      // poseBuffer는 VNHumanBodyPoseObservation가 30개 들어있는 배열
      for (frameIndex, observation) in poseBuffer.enumerated() {
        // frameIndex는 현재 프레임 (0 ~ 29)
        // observation은 한 개의 프레임
        
        let points = try observation.recognizedPoints(.all) // 한 개의 프레임에서 모든 관절 좌표 추출
        
        for (jointIndex, joint) in jointNames.enumerated() {
          // 18개의 관절 배열 순회하면서, jointIndex 현재 관절이 몇 번째인지
          // ex)
          if let point = points[joint] {
            // x축 ex) array[5, 0, 3] = 0.45 ➡️ 5번째 프레임의 3번째(leftEar) 관절의 x축 좌표는 0.45이다
            array[[frameIndex as NSNumber, 0, jointIndex as NSNumber]] = NSNumber(value: Float(point.location.x))
            // y축 ex) array[1, 1, 15] = 0.1 ➡️ 첫번째 프레임의 15번째(leftHip) 관절의 y축 좌표는 0.1이다
            array[[frameIndex as NSNumber, 1, jointIndex as NSNumber]] = NSNumber(value: Float(point.location.y))
            // confidence ex) array[17, 2, 1] = 0.7 ➡️ 17번째 프레임의 첫번째(leftEye) 관절의 정확도는 0.7이다
            array[[frameIndex as NSNumber, 2, jointIndex as NSNumber]] = NSNumber(value: Float(point.confidence))
          } else {
            // 관절 못 찾으면 0.0으로 채우기
            array[[frameIndex as NSNumber, 0, jointIndex as NSNumber]] = 0
            array[[frameIndex as NSNumber, 1, jointIndex as NSNumber]] = 0
            array[[frameIndex as NSNumber, 2, jointIndex as NSNumber]] = 0
          }
        }
      }
      
      // 모델 예측
      let result = try model.prediction(poses: array)
      let label = result.label
      let confidence = result.labelProbabilities[label] ?? 0.0
      
      onPrediction?(label, confidence)
    } catch {
      print("Log: 예측 에러")
    }
  }
  
}
