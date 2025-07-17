//
//  SessionManager.swift
//  Pision
//
//  Created by rundo on 7/16/25.
//

import Foundation
import Combine

class SessionManager: ObservableObject {
  @Published var currentCoreScore: Float = 0
  @Published var currentAuxScore: Float = 0
  @Published var currentTotalScore: Float = 0
  @Published var totalFocusTime: Int = 0
  @Published var currentMLPrediction: String = "focus"
  @Published var currentMLConfidence: Double = 0.0
  
  // 세부 데이터 저장용
  private var lastCoreScoreDetailData: ScoreDetailData?
  private var lastAuxScoreDetailData: (avgYawChange: Float, snoozeRatio: Float, totalFrames: Int, blinkCountAux: Int, yawStabilityScore: Float, mlSnoozeScore: Float, blinkScoreAux: Float)?
  
  private var frameDataBuffer: [FrameData] = []
  private var scoreHistory: [ScoreData] = []
  private var sessionStartTime: Date = Date()
  private var lastCoreScoreTime: Date = Date()
  private var lastAuxScoreTime: Date = Date()
  private var focusSegments: [(start: Date, end: Date)] = []
  private var currentFocusStart: Date?
  
  // 30초/1분 간격 타이머
  private var coreScoreTimer: Timer?
  private var auxScoreTimer: Timer?
  
  init() {
    sessionStartTime = Date()
    lastCoreScoreTime = Date()
    lastAuxScoreTime = Date()
    startTimers()
  }
  
  deinit {
    coreScoreTimer?.invalidate()
    auxScoreTimer?.invalidate()
  }
  
  private func startTimers() {
    // CoreScore 계산 타이머 (30초마다)
    coreScoreTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
      self?.calculateCoreScore()
    }
    
    // AuxScore 계산 타이머 (60초마다)
    auxScoreTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
      self?.calculateAuxScore()
    }
  }
  
  func addFrameData(_ frameData: FrameData) {
    frameDataBuffer.append(frameData)
    
    // 2분치 데이터만 유지 (메모리 관리)
    let cutoffTime = Date().addingTimeInterval(-120)
    frameDataBuffer = frameDataBuffer.filter { $0.timestamp > cutoffTime }
  }
  
  func updateMLPrediction(_ prediction: String, confidence: Double) {
    currentMLPrediction = prediction
    currentMLConfidence = confidence
  }
  
  private func calculateCoreScore() {
    let thirtySecondsAgo = Date().addingTimeInterval(-30)
    let recentFrames = frameDataBuffer.filter { $0.timestamp >= thirtySecondsAgo }
    
    guard !recentFrames.isEmpty else { return }
    
    let input = CoreScoreInput(
      yawValues: recentFrames.map { $0.yaw },
      earValues: recentFrames.map { $0.ear },
      blinkCount: recentFrames.filter { $0.blinkDetected }.count,
      frameRate: 30
    )
    
    let (coreScore, detailData) = ScoreCalculator.calculateCoreScoreWithDetails(input: input)
    
    DispatchQueue.main.async {
      self.currentCoreScore = coreScore
      self.lastCoreScoreDetailData = detailData
      self.updateTotalScore()
    }
  }
  
  private func calculateAuxScore() {
    let oneMinuteAgo = Date().addingTimeInterval(-60)
    let recentFrames = frameDataBuffer.filter { $0.timestamp >= oneMinuteAgo }
    
    guard !recentFrames.isEmpty else { return }
    
    // yaw 변화량 계산
    let yawChanges = zip(recentFrames.dropFirst(), recentFrames.dropLast()).map { current, previous in
      abs(current.yaw - previous.yaw)
    }
    
    // CoreML 예측 결과 기반 snooze 판정
    let snoozePredictions = recentFrames.map { frame in
      frame.mlPrediction == "snooze" || frame.ear < 0.18 || abs(frame.yaw) > 0.3
    }
    
    let input = AuxScoreInput(
      blinkCount: recentFrames.filter { $0.blinkDetected }.count,
      yawChanges: yawChanges,
      snoozePredictions: snoozePredictions,
      mlPredictions: recentFrames.compactMap { $0.mlPrediction }
    )
    
    let (auxScore, auxDetailData) = ScoreCalculator.calculateAuxScoreWithDetails(input: input)
    
    DispatchQueue.main.async {
      self.currentAuxScore = auxScore
      self.lastAuxScoreDetailData = auxDetailData
      self.updateTotalScore()
    }
  }
  
  private func updateTotalScore() {
    let totalScore = currentCoreScore * 0.7 + currentAuxScore * 0.3
    currentTotalScore = totalScore
    
    let isFocused = totalScore >= 50
    
    // 집중 구간 추적
    if isFocused && currentFocusStart == nil {
      currentFocusStart = Date()
    } else if !isFocused && currentFocusStart != nil {
      if let start = currentFocusStart {
        focusSegments.append((start: start, end: Date()))
        currentFocusStart = nil
      }
    }
    
    // 총 집중 시간 계산
    var totalSeconds = 0
    for segment in focusSegments {
      totalSeconds += Int(segment.end.timeIntervalSince(segment.start))
    }
    
    // 현재 집중 중인 시간 추가
    if let start = currentFocusStart {
      totalSeconds += Int(Date().timeIntervalSince(start))
    }
    
    totalFocusTime = totalSeconds
    
    // 점수 히스토리 저장
    let combinedDetailData: ScoreDetailData?
    if let coreDetail = lastCoreScoreDetailData {
      combinedDetailData = ScoreDetailData(
        avgYaw: coreDetail.avgYaw,
        avgEAR: coreDetail.avgEAR,
        eyeClosedRatio: coreDetail.eyeClosedRatio,
        blinkCount: coreDetail.blinkCount,
        yawScore: coreDetail.yawScore,
        eyeOpenScore: coreDetail.eyeOpenScore,
        eyeClosedScore: coreDetail.eyeClosedScore,
        blinkScore: coreDetail.blinkScore,
        avgYawChange: lastAuxScoreDetailData?.avgYawChange,
        snoozeRatio: lastAuxScoreDetailData?.snoozeRatio,
        totalFrames: lastAuxScoreDetailData?.totalFrames,
        blinkCountAux: lastAuxScoreDetailData?.blinkCountAux,
        yawStabilityScore: lastAuxScoreDetailData?.yawStabilityScore,
        mlSnoozeScore: lastAuxScoreDetailData?.mlSnoozeScore,
        blinkScoreAux: lastAuxScoreDetailData?.blinkScoreAux
      )
    } else {
      combinedDetailData = nil
    }
    
    let scoreData = ScoreData(
      timestamp: Date(),
      coreScore: currentCoreScore,
      auxScore: currentAuxScore,
      totalScore: currentTotalScore,
      isFocused: isFocused,
      mlPrediction: currentMLPrediction,
      mlConfidence: currentMLConfidence,
      detailData: combinedDetailData
    )
    scoreHistory.append(scoreData)
  }
  
  func getSessionData() -> SessionData {
    // 현재 집중 중인 구간이 있다면 종료
    if let start = currentFocusStart {
      focusSegments.append((start: start, end: Date()))
    }
    
    let endTime = Date()
    let totalDuration = endTime.timeIntervalSince(sessionStartTime)
    let averageScore = scoreHistory.isEmpty ? 0 : scoreHistory.map { $0.totalScore }.reduce(0, +) / Float(scoreHistory.count)
    
    return SessionData(
      startTime: sessionStartTime,
      endTime: endTime,
      totalDuration: totalDuration,
      totalFocusTime: totalFocusTime,
      averageScore: averageScore,
      scoreHistory: scoreHistory,
      focusSegments: focusSegments
    )
  }
}
