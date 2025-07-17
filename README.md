# 2025-C4-A12-Pision

✅ 집중도 측정 전체 흐름 요약 및 상세 구조
📌 전체 흐름 개요
scss


카메라 영상 입력
   ↓
Vision 프레임 분석 (얼굴, 포즈, EAR, yaw, blink)
   ↓
ML 모델 예측 (30프레임 누적 시)
   ↓
프레임 기록 (yaw, EAR, blink, ML 결과)
   ↓
점수 계산 (30초마다 Core, 60초마다 Aux)
   ↓
집중 여부 판단 → 집중 시간 측정
   ↓
세션 종료 시 결과 요약 및 기록
🧩 1단계: 실시간 카메라 입력
📁 파일: CameraManager.swift
📌 핵심 코드:




videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
→ 프레임 수신 시 VisionManager로 전달:




func captureOutput(...) {
  visionManager.processFaceLandMark(pixelBuffer: pixelBuffer)
  visionManager.processBodyPose(pixelBuffer: pixelBuffer)
}
🧩 2단계: Vision 프레임 분석
📁 파일: VisionManager.swift

🧠 얼굴 분석 (Yaw, Roll, EAR, Blink)



VNDetectFaceLandmarksRequest
yaw, roll → 고개 방향 정보

EAR 계산 → 눈 감김 비율

EAR < 0.2 && 0.3초 이상 간격 → 깜빡임으로 간주 → blinkCount++

📌 클로저 전달:




onFaceDetection?(faces, yaws, rolls)
onBlinkDetection?(ear, isBlinking, blinkCount)
🧍‍♂️ 신체 포즈 분석 (ML용 입력)



VNDetectHumanBodyPoseRequest
관절 데이터 추출 → MLManager.addPoseObservation

📌 클로저 전달:




onPoseDetection?(observation)
🧩 3단계: ML 모델 예측
📁 파일: MLManager.swift

조건



if poseBuffer.count == 30 { bodyPosePredict() }
입력 구조



[30, 3, 18] → (30프레임, 좌표축[x, y, conf], 관절 18개)
출력 결과



let label = result.label // ex: "focus", "snooze"
let confidence = result.labelProbabilities[label]
📌 클로저 전달:




onPrediction?(label, confidence)
🧩 4단계: 프레임 데이터 기록
📁 파일: SessionManager.swift




func addFrameData(_ frameData: FrameData)
저장 내용 (FrameData)



struct FrameData {
  let timestamp: Date
  let yaw: Float
  let ear: Float
  let blinkDetected: Bool
  let mlPrediction: String?
  let mlConfidence: Double?
}
2분 이상 지난 프레임은 자동 제거

🧩 5단계: 점수 계산
📁 파일: SessionManager.

🧮 5-1. Core Score 계산 (30초 주기)



calculateCoreScore()
⏱ 사용 데이터
최근 30초 프레임

yaw, EAR, blinkCount, frameRate

💯 계산 항목 및 가중치
항목	설명	계산식	가중치
yawScore	고개 흔들림 정도	(1 - normalize(avgYaw, 0 ~ 0.4)) * 100	0.4
eyeOpenScore	눈을 얼마나 떴는지	normalize(avgEAR, 0.15 ~ 0.35) * 100	0.25
eyeClosedScore	눈을 덜 감았는지	(1 - eyeClosedRatio) * 100	0.2
blinkScore	깜빡임이 적은지	(1 - normalize(blinkPerMinute, 0 ~ 30)) * 100	0.15

🧾 결과



coreScore = yawScore + eyeOpenScore + eyeClosedScore + blinkScore
📦 함께 저장: ScoreDetailData

📡 5-2. Aux Score 계산 (60초 주기)



calculateAuxScore()
⏱ 사용 데이터
최근 60초 프레임

yaw 변화량, blinkCount, snoozePredictions, mlPredictions

💯 계산 항목 및 가중치
항목	설명	계산식	가중치
blinkScoreAux	깜빡임 빈도	(1 - normalize(blinkCount, 0 ~ 30)) * 100	0.25
yawStabilityScore	고개 안정성	(1 - normalize(avgYawChange, 0 ~ 0.2)) * 100	0.25
mlSnoozeScore	졸음 예측 비율	(1 - snoozeRatio)^2 * 100	0.5

snooze 예측 조건



mlPrediction == "snooze" || ear < 0.18 || abs(yaw) > 0.3
📦 함께 저장: ScoreDetailData

🧮 6단계: Total Score 계산 + 집중 추적
📁 파일: SessionManager.swift




currentTotalScore = coreScore * 0.7 + auxScore * 0.3
집중 여부 판단



let isFocused = totalScore >= 50
집중 상태 시작 → currentFocusStart = Date()

집중 해제 → (start, end) 쌍으로 focusSegments에 저장

집중 시간 누적



totalFocusTime = sum(focusSegment.duration)
📊 7단계: 세션 종료 시 데이터 요약
📁 파일: getSessionData()




SessionData(
  startTime: sessionStartTime,
  endTime: Date(),
  totalDuration: end - start,
  totalFocusTime: totalFocusTime,
  averageScore: mean(scoreHistory.totalScore),
  scoreHistory: [ScoreData],
  focusSegments: [(start, end)]
)
📦 핵심 데이터 구조 요약
FrameData



struct FrameData {
  let timestamp: Date
  let yaw: Float
  let ear: Float
  let blinkDetected: Bool
  let mlPrediction: String?
  let mlConfidence: Double?
}
ScoreDetailData



struct ScoreDetailData {
  let avgYaw, avgEAR, eyeClosedRatio, blinkCount
  let yawScore, eyeOpenScore, eyeClosedScore, blinkScore
  let avgYawChange, snoozeRatio, totalFrames, blinkCountAux
  let yawStabilityScore, mlSnoozeScore, blinkScoreAux
}
ScoreData



struct ScoreData {
  let timestamp: Date
  let coreScore: Float
  let auxScore: Float?
  let totalScore: Float
  let isFocused: Bool
  let mlPrediction: String?
  let mlConfidence: Double?
  let detailData: ScoreDetailData?
}
SessionData



struct SessionData {
  let startTime: Date
  let endTime: Date
  let totalDuration: TimeInterval
  let totalFocusTime: Int
  let averageScore: Float
  let scoreHistory: [ScoreData]
  let focusSegments: [(start: Date, end: Date)]
}
🔁 전체 클로저 흐름 트레이스 (한눈에 정리)
plaintext


카메라 프레임
 ↓
CameraManager.captureOutput
 ↓
VisionManager.processFaceLandMark / processBodyPose
 ↓
  ├─ onFaceDetection → CameraManager → ViewModel
  ├─ onBlinkDetection → SessionManager.addFrameData
  └─ onPoseDetection → MLManager.addPoseObservation
                          ↓
                      MLManager.bodyPosePredict
                          ↓
                      onPrediction → VisionManager → onMLPrediction → SessionManager.updateMLPrediction
✅ 핵심 요약 문장
Vision으로 얼굴과 포즈를 인식해 EAR, yaw, blink, ML 예측 결과를 추출하고, 이를 매 프레임마다 기록해 30초/60초 주기로 Core/Aux 집중 점수를 계산한 후, 집중 지속 여부에 따라 시간 구간을 추적하고, 세션 종료 시 전체 집중 시간과 평균 집중 점수를 SessionData로 저장합니다.
