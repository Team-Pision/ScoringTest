import AVFoundation
import SwiftUI
import CoreML

struct RecordView: View {
  @StateObject private var cameraManager = CameraManager()
  @State private var sessionManager = SessionManager()
  
  @State private var timerTime = 0
  @State private var timerRunning = true
  @State private var timer: Timer? = nil
  @State private var scoreTimer: Timer? = nil
  
  @State private var savedBrightness: CGFloat = UIScreen.main.brightness
  @State private var brightnessResetWorkItem: DispatchWorkItem?
  @State private var isDimmed = false
  
  @State private var showingResults = false
  
  // 실시간 분석 데이터
  @State private var currentYaw: Double = 0
  @State private var currentEAR: Float = 0.25
  @State private var blinkCount: Int = 0
  @State private var blinkJustDetected: Bool = false
  @State private var currentMLPrediction: String = "focus"
  @State private var currentMLConfidence: Double = 0.0
  
  init() {
    // 초기화 로직은 onAppear에서 처리
  }
  
  var body: some View {
    NavigationView {
      ZStack {
        Color.clear.ignoresSafeArea()
        VStack {
          ZStack {
            CameraView(session: cameraManager.session)
            
            VStack {
              // 실시간 점수 표시
              VStack {
                Text("집중도: \(Int(sessionManager.currentTotalScore))/100")
                  .font(.title2)
                  .foregroundColor(sessionManager.currentTotalScore >= 50 ? .green : .red)
                
                Text("집중 시간: \(formatTime(sessionManager.totalFocusTime))")
                  .font(.headline)
                  .foregroundColor(.blue)
                
                // ML 예측 결과 표시
                VStack {
                  Text("AI 분석: \(currentMLPrediction)")
                    .font(.subheadline)
                    .foregroundColor(currentMLPrediction == "focus" ? .green : .red)
                  
                  Text("정확도: \(Int(currentMLConfidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .padding()
              .background(Color.black.opacity(0.7))
              .cornerRadius(10)
              
              Spacer()
              
              Text(timeString(from: timerTime))
                .font(.largeTitle)
                .foregroundColor(.white)
                .shadow(radius: 2)
              
              Spacer()
              
              HStack {
                Spacer()
                
                Button("정지") {
                  stopRecording()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Spacer()
                
                Button(timerRunning ? "일시정지" : "다시시작") {
                  timerRunning.toggle()
                  if timerRunning {
                    startTimer()
                    startScoreTimer()
                  } else {
                    stopTimer()
                    stopScoreTimer()
                  }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Spacer()
              }
              
              Spacer()
              
              Button(isDimmed ? "밝기 복구" : "밝기 낮추기") {
                isDimmed.toggle()
                isDimmed ? setLowestBrightness() : restoreBrightness()
              }
              .buttonStyle(.bordered)
              .padding(.bottom, 10)
            }
          }
          
          // 디버그 정보
          VStack {
            Text("yaw: \(String(format: "%.2f", currentYaw))")
            Text("EAR: \(String(format: "%.3f", currentEAR))")
            Text("깜빡임: \(blinkCount)")
            Text("CoreScore: \(Int(sessionManager.currentCoreScore))")
            Text("AuxScore: \(Int(sessionManager.currentAuxScore))")
            Text("ML: \(currentMLPrediction) (\(String(format: "%.1f", currentMLConfidence * 100))%)")
          }
          .font(.caption)
          .foregroundColor(.gray)
        }
      }
      .onAppear {
        savedBrightness = UIScreen.main.brightness
        setupCameraCallbacks()
        cameraManager.requestAndCheckPermissions()
        cameraManager.startSession()
        startTimer()
        startScoreTimer()
        isDimmed = false
      }
      .onDisappear {
        cameraManager.stopSession()
        stopTimer()
        stopScoreTimer()
        restoreBrightness()
      }
      .onTapGesture {
        showBrightnessTemporarily()
      }
      .sheet(isPresented: $showingResults) {
        ResultsView(sessionData: sessionManager.getSessionData())
      }
    }
  }
  
  private func stopRecording() {
    stopTimer()
    stopScoreTimer()
    cameraManager.stopSession()
    showingResults = true
  }
  
  private func setupCameraCallbacks() {
    // Yaw 각도 업데이트
    cameraManager.onYawsUpdate = { yaws in
      if let lastYaw = yaws.last {
        self.currentYaw = lastYaw
      }
    }
    
    // 블링크 감지 콜백 설정
    cameraManager.visionManager.onBlinkDetection = { ear, isBlinking, totalBlinkCount in
      self.currentEAR = ear
      self.blinkCount = totalBlinkCount
      if isBlinking {
        self.blinkJustDetected = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          self.blinkJustDetected = false
        }
      }
    }
    
    // ML 예측 결과 콜백 설정
    cameraManager.visionManager.onMLPrediction = { prediction, confidence in
      self.currentMLPrediction = prediction
      self.currentMLConfidence = confidence
      self.sessionManager.updateMLPrediction(prediction, confidence: confidence)
    }
  }
  
  private func startScoreTimer() {
    scoreTimer?.invalidate()
    scoreTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      DispatchQueue.main.async {
        // 매초마다 데이터 수집 (ML 예측 결과 포함)
        let frameData = FrameData(
          timestamp: Date(),
          yaw: Float(currentYaw),
          ear: currentEAR,
          blinkDetected: blinkJustDetected,
          mlPrediction: currentMLPrediction,
          mlConfidence: currentMLConfidence
        )
        sessionManager.addFrameData(frameData)
      }
    }
  }
  
  private func stopScoreTimer() {
    scoreTimer?.invalidate()
  }
}

// MARK: - Timer Extensions
extension RecordView {
  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      DispatchQueue.main.async {
        timerTime += 1
      }
    }
  }
  
  private func stopTimer() {
    timer?.invalidate()
  }
  
  private func timeString(from seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, secs)
  }
  
  private func formatTime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, secs)
  }
  
  private func setLowestBrightness() {
    DispatchQueue.main.async {
      UIScreen.main.brightness = 0.01
    }
  }
  
  private func restoreBrightness() {
    DispatchQueue.main.async {
      UIScreen.main.brightness = savedBrightness
    }
  }
  
  private func showBrightnessTemporarily() {
    brightnessResetWorkItem?.cancel()
    
    restoreBrightness()
    
    let workItem = DispatchWorkItem {
      if isDimmed {
        setLowestBrightness()
      }
    }
    brightnessResetWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
  }
}

#Preview {
  RecordView()
}
