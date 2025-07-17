import SwiftUI

struct ResultsView: View {
  let sessionData: SessionData
  @Environment(\.dismiss) private var dismiss
  @State private var selectedScoreIndex: Int? = nil
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 30) {
          // 총 집중시간
          totalFocusTimeSection
          
          // 타임라인별 점수
          scoreTimelineSection
        }
        .padding()
      }
      .navigationTitle("분석 결과")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("완료") {
            dismiss()
          }
        }
      }
    }
  }
  
  private var totalFocusTimeSection: some View {
    VStack(spacing: 10) {
      Text("총 집중시간")
        .font(.title2)
      
      Text(formatTime(sessionData.totalFocusTime))
        .font(.largeTitle)
        .foregroundColor(.blue)
      
      Text("전체 시간: \(formatDuration(sessionData.totalDuration))")
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
  }
  
  private var scoreTimelineSection: some View {
    VStack(spacing: 15) {
      Text("점수 타임라인")
        .font(.title2)
      
      Text("항목을 탭하면 세부 계산 내역을 볼 수 있습니다")
        .font(.caption)
        .foregroundColor(.secondary)
      
      ForEach(Array(sessionData.scoreHistory.enumerated()), id: \.offset) { index, score in
        VStack(spacing: 10) {
          // 메인 점수 항목
          HStack {
            Text(timeFormatter.string(from: score.timestamp))
              .frame(width: 80, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
              Text("총점: \(Int(score.totalScore))")
              Text("Core: \(Int(score.coreScore))")
              if let auxScore = score.auxScore {
                Text("Aux: \(Int(auxScore))")
              }
            }
            .font(.caption)
            
            Spacer()
            
            Text(score.isFocused ? "집중" : "비집중")
              .foregroundColor(score.isFocused ? .green : .red)
              .font(.caption)
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .background(score.isFocused ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
          .onTapGesture {
            selectedScoreIndex = selectedScoreIndex == index ? nil : index
          }
          
          // 선택된 항목의 세부 내역
          if selectedScoreIndex == index {
            scoreDetailView(score: score)
              .padding(.horizontal, 12)
          }
        }
      }
    }
  }
  
  private func scoreDetailView(score: ScoreData) -> some View {
    VStack(spacing: 15) {
      // CoreScore 세부 내역
      coreScoreDetailView(score: score)
      
      // AuxScore 세부 내역 (있는 경우)
      if score.auxScore != nil {
        auxScoreDetailView(score: score)
      }
      
      // TotalScore 계산
      totalScoreCalculationView(score: score)
    }
    .padding()
    .background(Color.gray.opacity(0.05))
  }
  
  private func coreScoreDetailView(score: ScoreData) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("CoreScore 구성 (30초 단위)")
        .font(.headline)
        .foregroundColor(.green)
      
      if let detail = score.detailData {
        VStack(alignment: .leading, spacing: 4) {
          Text("• 고개 자세 (40%): \(Int(detail.yawScore))점")
          Text("  - 평균 yaw: \(String(format: "%.3f", detail.avgYaw))° (정면에서 벗어난 정도)")
          
          Text("• 눈 뜸 상태 (25%): \(Int(detail.eyeOpenScore))점")
          Text("  - 평균 EAR: \(String(format: "%.3f", detail.avgEAR)) (눈 뜸 정도)")
          
          Text("• 눈 감은 시간 (20%): \(Int(detail.eyeClosedScore))점")
          Text("  - 눈 감은 비율: \(String(format: "%.1f", detail.eyeClosedRatio * 100))%")
          
          Text("• 깜빡임 빈도 (15%): \(Int(detail.blinkScore))점")
          Text("  - 30초간 깜빡임: \(detail.blinkCount)회 (분당 \(detail.blinkCount * 2)회)")
        }
        .font(.caption)
        .foregroundColor(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 4) {
          Text("• 고개 자세 (40%): \(Int(score.coreScore * 0.4))점")
          Text("• 눈 뜸 상태 (25%): \(Int(score.coreScore * 0.25))점")
          Text("• 눈 감은 시간 (20%): \(Int(score.coreScore * 0.2))점")
          Text("• 깜빡임 빈도 (15%): \(Int(score.coreScore * 0.15))점")
        }
        .font(.caption)
        .foregroundColor(.secondary)
      }
      
      Text("CoreScore: \(Int(score.coreScore))점")
        .font(.subheadline)
        .foregroundColor(.green)
    }
  }
  
  private func auxScoreDetailView(score: ScoreData) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("AuxScore 구성 (1분 단위)")
        .font(.headline)
        .foregroundColor(.orange)
      
      if let auxScore = score.auxScore, let detail = score.detailData {
        VStack(alignment: .leading, spacing: 4) {
          if let blinkScoreAux = detail.blinkScoreAux, let blinkCountAux = detail.blinkCountAux {
            Text("• 깜빡임 빈도 (25%): \(Int(blinkScoreAux))점")
            Text("  - 1분간 깜빡임: \(blinkCountAux)회")
          }
          
          if let yawStabilityScore = detail.yawStabilityScore, let avgYawChange = detail.avgYawChange {
            Text("• 고개 흔들림 (25%): \(Int(yawStabilityScore))점")
            Text("  - 평균 yaw 변화량: \(String(format: "%.4f", avgYawChange))°")
          }
          
          if let mlSnoozeScore = detail.mlSnoozeScore, let snoozeRatio = detail.snoozeRatio, let totalFrames = detail.totalFrames {
            Text("• AI 졸음 감지 (50%): \(Int(mlSnoozeScore))점")
            Text("  - snooze 판정: \(Int(snoozeRatio * 100))% (\(Int(snoozeRatio * Float(totalFrames)))/\(totalFrames) 프레임)")
          }
          
          if let prediction = score.mlPrediction, let confidence = score.mlConfidence {
            Text("  → AI 예측: \(prediction) (정확도: \(Int(confidence * 100))%)")
              .foregroundColor(prediction == "focus" ? .green : .red)
          }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        
        Text("AuxScore: \(Int(auxScore))점")
          .font(.subheadline)
          .foregroundColor(.orange)
      } else if let auxScore = score.auxScore {
        VStack(alignment: .leading, spacing: 4) {
          Text("• 깜빡임 빈도 (25%): \(Int(auxScore * 0.25))점")
          Text("• 고개 흔들림 (25%): \(Int(auxScore * 0.25))점")
          Text("• AI 졸음 감지 (50%): \(Int(auxScore * 0.5))점")
          
          if let prediction = score.mlPrediction, let confidence = score.mlConfidence {
            Text("  → 예측: \(prediction) (정확도: \(Int(confidence * 100))%)")
              .foregroundColor(prediction == "focus" ? .green : .red)
          }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        
        Text("AuxScore: \(Int(auxScore))점")
          .font(.subheadline)
          .foregroundColor(.orange)
      }
    }
  }
  
  private func totalScoreCalculationView(score: ScoreData) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("TotalScore 계산")
        .font(.headline)
        .foregroundColor(.blue)
      
      VStack(alignment: .leading, spacing: 4) {
        Text("• CoreScore × 0.7 = \(Int(score.coreScore)) × 0.7 = \(Int(score.coreScore * 0.7))점")
        
        if let auxScore = score.auxScore {
          Text("• AuxScore × 0.3 = \(Int(auxScore)) × 0.3 = \(Int(auxScore * 0.3))점")
        } else {
          Text("• AuxScore × 0.3 = 0 × 0.3 = 0점 (1분 미만)")
        }
        
        Text("• 합계 = \(Int(score.totalScore))점")
      }
      .font(.caption)
      .foregroundColor(.secondary)
      
      Text("TotalScore: \(Int(score.totalScore))점 (\(score.isFocused ? "집중" : "비집중"))")
        .font(.subheadline)
        .foregroundColor(score.isFocused ? .green : .red)
      
      Text("* 50점 이상이면 집중 상태로 판정")
        .font(.caption2)
        .foregroundColor(.secondary)
    }
  }
  
  private var timeFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }
  
  private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
  }
  
  private func formatTime(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, secs)
  }
}

#Preview {
  let sampleDetailData = ScoreDetailData(
    avgYaw: 0.12, avgEAR: 0.28, eyeClosedRatio: 0.15, blinkCount: 8,
    yawScore: 28.8, eyeOpenScore: 21.25, eyeClosedScore: 17.0, blinkScore: 12.75,
    avgYawChange: 0.08, snoozeRatio: 0.3, totalFrames: 60, blinkCountAux: 15,
    yawStabilityScore: 20.0, mlSnoozeScore: 35.0, blinkScoreAux: 18.75
  )
  
  let sampleData = SessionData(
    startTime: Date().addingTimeInterval(-3600),
    endTime: Date(),
    totalDuration: 3600,
    totalFocusTime: 2400,
    averageScore: 75.5,
    scoreHistory: [
      ScoreData(timestamp: Date().addingTimeInterval(-3600), coreScore: 80, auxScore: 70, totalScore: 77, isFocused: true, mlPrediction: "focus", mlConfidence: 0.85, detailData: sampleDetailData),
      ScoreData(timestamp: Date().addingTimeInterval(-3000), coreScore: 60, auxScore: 50, totalScore: 57, isFocused: true, mlPrediction: "focus", mlConfidence: 0.75, detailData: sampleDetailData),
      ScoreData(timestamp: Date().addingTimeInterval(-2400), coreScore: 40, auxScore: 30, totalScore: 37, isFocused: false, mlPrediction: "snooze", mlConfidence: 0.90, detailData: sampleDetailData),
      ScoreData(timestamp: Date().addingTimeInterval(-1800), coreScore: 85, auxScore: 80, totalScore: 83, isFocused: true, mlPrediction: "focus", mlConfidence: 0.95, detailData: sampleDetailData),
      ScoreData(timestamp: Date().addingTimeInterval(-1200), coreScore: 75, auxScore: 65, totalScore: 72, isFocused: true, mlPrediction: "focus", mlConfidence: 0.80, detailData: sampleDetailData),
      ScoreData(timestamp: Date().addingTimeInterval(-600), coreScore: 45, auxScore: 35, totalScore: 42, isFocused: false, mlPrediction: "snooze", mlConfidence: 0.88, detailData: sampleDetailData)
    ],
    focusSegments: [
      (start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(-2700)),
      (start: Date().addingTimeInterval(-2100), end: Date().addingTimeInterval(-900)),
      (start: Date().addingTimeInterval(-300), end: Date())
    ]
  )
  
  ResultsView(sessionData: sampleData)
}
