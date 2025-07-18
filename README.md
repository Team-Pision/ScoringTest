# 📌 Pision 집중도 측정 로직 정리

## ✅ 전체 흐름 요약

```
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
```

---

## 🧩 1단계: 실시간 카메라 입력

📁 **파일**: `CameraManager.swift`  
📌 **핵심 코드**:

```swift
videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

func captureOutput(...) {
  visionManager.processFaceLandMark(pixelBuffer: pixelBuffer)
  visionManager.processBodyPose(pixelBuffer: pixelBuffer)
}
```

---

## 🧩 2단계: Vision 프레임 분석

📁 **파일**: `VisionManager.swift`

### 🧠 얼굴 분석 (Yaw, Roll, EAR, Blink)

- `VNDetectFaceLandmarksRequest`
- `EAR < 0.2` && `0.3초 간격 이상` → 깜빡임으로 간주 → `blinkCount++`

📌 클로저:

```swift
onFaceDetection?(faces, yaws, rolls)
onBlinkDetection?(ear, isBlinking, blinkCount)
```

### 🧍‍♂️ 포즈 분석

- `VNDetectHumanBodyPoseRequest` → 관절 정보 추출 → MLManager로 전달

📌 클로저:

```swift
onPoseDetection?(observation)
```

---

## 🧩 3단계: ML 모델 예측

📁 **파일**: `MLManager.swift`

- 포즈 버퍼 30개 모이면 예측 시작

```swift
if poseBuffer.count == 30 { bodyPosePredict() }
```

- 입력 형식: `[30, 3, 18]` (프레임, 좌표축, 관절)
- 출력 결과:

```swift
let label = result.label // "focus", "snooze"
let confidence = result.labelProbabilities[label]
```

📌 클로저:

```swift
onPrediction?(label, confidence)
```

---

## 🧩 4단계: 프레임 데이터 기록

📁 **파일**: `SessionManager.swift`

```swift
func addFrameData(_ frameData: FrameData)
```

### 저장 구조

```swift
struct FrameData {
  let timestamp: Date
  let yaw: Float
  let ear: Float
  let blinkDetected: Bool
  let mlPrediction: String?
  let mlConfidence: Double?
}
```

- 최대 2분치만 유지

---

## 🧩 5단계: 점수 계산

📁 **파일**: `SessionManager.swift`

---

### 🧮 Core Score (30초 주기)

```swift
calculateCoreScore()
```

| 항목           | 설명               | 계산식                                          | 가중치 |
| -------------- | ------------------ | ----------------------------------------------- | ------ |
| yawScore       | 고개 흔들림 정도   | `(1 - normalize(avgYaw, 0 ~ 0.4)) * 100`        | 0.4    |
| eyeOpenScore   | 눈을 얼마나 떴는지 | `normalize(avgEAR, 0.15 ~ 0.35) * 100`          | 0.25   |
| eyeClosedScore | 눈을 덜 감았는지   | `(1 - eyeClosedRatio) * 100`                    | 0.2    |
| blinkScore     | 깜빡임이 적은지    | `(1 - normalize(blinkPerMinute, 0 ~ 30)) * 100` | 0.15   |

```swift
coreScore = yawScore + eyeOpenScore + eyeClosedScore + blinkScore
```

📦 저장: `ScoreDetailData`

---

### 📡 Aux Score (60초 주기)

```swift
calculateAuxScore()
```

| 항목              | 설명           | 계산식                                         | 가중치 |
| ----------------- | -------------- | ---------------------------------------------- | ------ |
| blinkScoreAux     | 깜빡임 빈도    | `(1 - normalize(blinkCount, 0 ~ 30)) * 100`    | 0.25   |
| yawStabilityScore | 고개 안정성    | `(1 - normalize(avgYawChange, 0 ~ 0.2)) * 100` | 0.25   |
| mlSnoozeScore     | 졸음 예측 비율 | `(1 - snoozeRatio)^2 * 100`                    | 0.5    |

#### snooze 조건:

```swift
mlPrediction == "snooze" || ear < 0.18 || abs(yaw) > 0.3
```

📦 저장: `ScoreDetailData`

---

## 🧩 6단계: Total Score + 집중 추적

```swift
currentTotalScore = coreScore * 0.7 + auxScore * 0.3
```

### 집중 판단

```swift
let isFocused = totalScore >= 50
```

- 시작 시 `currentFocusStart = Date()`
- 해제 시 `(start, end)` → `focusSegments` 기록

```swift
totalFocusTime = sum(focusSegments.map { $0.end - $0.start })
```

---

## 🧩 7단계: 세션 종료 결과 생성

📁 `getSessionData()`

```swift
SessionData(
  startTime: sessionStartTime,
  endTime: Date(),
  totalDuration: end - start,
  totalFocusTime: totalFocusTime,
  averageScore: mean(scoreHistory.map { $0.totalScore }),
  scoreHistory: [ScoreData],
  focusSegments: [(start, end)]
)
```

---

## 🧱 핵심 데이터 구조 요약

### `FrameData`

```swift
struct FrameData {
  let timestamp: Date
  let yaw: Float
  let ear: Float
  let blinkDetected: Bool
  let mlPrediction: String?
  let mlConfidence: Double?
}
```

### `ScoreDetailData`

```swift
struct ScoreDetailData {
  let avgYaw, avgEAR, eyeClosedRatio, blinkCount: Float
  let yawScore, eyeOpenScore, eyeClosedScore, blinkScore: Float
  let avgYawChange, snoozeRatio, totalFrames, blinkCountAux: Float?
  let yawStabilityScore, mlSnoozeScore, blinkScoreAux: Float?
}
```

### `ScoreData`

```swift
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
```

### `SessionData`

```swift
struct SessionData {
  let startTime: Date
  let endTime: Date
  let totalDuration: TimeInterval
  let totalFocusTime: Int
  let averageScore: Float
  let scoreHistory: [ScoreData]
  let focusSegments: [(start: Date, end: Date)]
}
```

---

## 🔁 전체 클로저 흐름 정리

```text
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
```

---

## ✅ 최종 요약

> Vision으로 얼굴과 포즈를 인식해 EAR, yaw, blink, ML 예측 결과를 추출하고, 이를 매 프레임마다 기록해 30초/60초 주기로 Core/Aux 집중 점수를 계산한 후, 집중 지속 여부에 따라 시간 구간을 추적하고, 세션 종료 시 전체 집중 시간과 평균 집중 점수를 `SessionData`로 저장합니다.
