//
//  ScoreCalculator.swift
//  Pision
//
//  Created by rundo on 7/16/25.
//

import Foundation // pow 쓰기위해

struct CoreScoreInput {
  let yawValues: [Float]
  let earValues: [Float]
  let blinkCount: Int
  let frameRate: Int
}

struct AuxScoreInput {
  let blinkCount: Int
  let yawChanges: [Float]
  let snoozePredictions: [Bool]
  let mlPredictions: [String] // ML 예측 결과 추가
}

struct ScoreCalculator {
  static func calculateCoreScoreWithDetails(input: CoreScoreInput) -> (Float, ScoreDetailData) {
    guard !input.yawValues.isEmpty && !input.earValues.isEmpty else {
      let emptyDetail = ScoreDetailData(
        avgYaw: 0, avgEAR: 0, eyeClosedRatio: 0, blinkCount: 0,
        yawScore: 0, eyeOpenScore: 0, eyeClosedScore: 0, blinkScore: 0,
        avgYawChange: nil, snoozeRatio: nil, totalFrames: nil, blinkCountAux: nil,
        yawStabilityScore: nil, mlSnoozeScore: nil, blinkScoreAux: nil
      )
      return (0, emptyDetail)
    }
    
    // 측정값 계산
    let avgYaw = input.yawValues.map { abs($0) }.average()
    let avgEAR = input.earValues.average()
    let closedCount = input.earValues.filter { $0 < 0.2 }.count
    let eyeClosedRatio = Float(closedCount) / Float(input.earValues.count)
    
    // 각 항목별 점수 계산
    let yawScore = (1.0 - normalize(value: avgYaw, maxValue: 0.4)) * 100 * 0.4
    let eyeOpenScore = normalize(value: avgEAR, minValue: 0.15, maxValue: 0.35) * 100 * 0.25
    let eyeClosedScore = (1.0 - eyeClosedRatio) * 100 * 0.2
    let blinkPerMinute = Float(input.blinkCount) * 2.0
    let blinkScore = (1.0 - normalize(value: blinkPerMinute, maxValue: 30)) * 100 * 0.15
    
    let total = yawScore + eyeOpenScore + eyeClosedScore + blinkScore
    
    let detailData = ScoreDetailData(
      avgYaw: avgYaw,
      avgEAR: avgEAR,
      eyeClosedRatio: eyeClosedRatio,
      blinkCount: input.blinkCount,
      yawScore: yawScore,
      eyeOpenScore: eyeOpenScore,
      eyeClosedScore: eyeClosedScore,
      blinkScore: blinkScore,
      avgYawChange: nil, snoozeRatio: nil, totalFrames: nil, blinkCountAux: nil,
      yawStabilityScore: nil, mlSnoozeScore: nil, blinkScoreAux: nil
    )
    
    return (min(max(total, 0), 100), detailData)
  }
  
  static func calculateAuxScoreWithDetails(input: AuxScoreInput) -> (Float, (avgYawChange: Float, snoozeRatio: Float, totalFrames: Int, blinkCountAux: Int, yawStabilityScore: Float, mlSnoozeScore: Float, blinkScoreAux: Float)) {
    guard !input.yawChanges.isEmpty && !input.snoozePredictions.isEmpty else {
      return (0, (0, 0, 0, 0, 0, 0, 0))
    }
    
    // 측정값 계산
    let avgYawChange = input.yawChanges.average()
    let snoozeCount = input.snoozePredictions.filter { $0 }.count
    let snoozeRatio = Float(snoozeCount) / Float(input.snoozePredictions.count)
    
    // 각 항목별 점수 계산
    let blinkScoreAux = max(0, 100 - normalize(value: Float(input.blinkCount), maxValue: 30)) * 0.25
    let yawStabilityScore = max(0, 100 - normalize(value: avgYawChange, maxValue: 0.2)) * 0.25
    let mlSnoozeScore = pow(1.0 - snoozeRatio, 2) * 100 * 0.5
    
    let total = blinkScoreAux + yawStabilityScore + mlSnoozeScore
    
    let detailData = (
      avgYawChange: avgYawChange,
      snoozeRatio: snoozeRatio,
      totalFrames: input.snoozePredictions.count,
      blinkCountAux: input.blinkCount,
      yawStabilityScore: yawStabilityScore,
      mlSnoozeScore: mlSnoozeScore,
      blinkScoreAux: blinkScoreAux
    )
    
    return (min(max(total, 0), 100), detailData)
  }
  
  // 기존 메서드들도 유지 (호환성을 위해)
  static func calculateCoreScore(input: CoreScoreInput) -> Float {
    return calculateCoreScoreWithDetails(input: input).0
  }
  
  static func calculateAuxScore(input: AuxScoreInput) -> Float {
    return calculateAuxScoreWithDetails(input: input).0
  }
  
  private static func normalize(value: Float, minValue: Float = 0, maxValue: Float) -> Float {
    guard maxValue != minValue else { return 0 }
    return min(max((value - minValue) / (maxValue - minValue), 0), 1)
  }
}
