//
//  Session+ScoreModel.swift
//  Pision
//
//  Created by rundo on 7/16/25.
//

import Foundation

// 프레임 데이터 구조체
struct FrameData {
    let timestamp: Date
    let yaw: Float
    let ear: Float
    let blinkDetected: Bool
    let mlPrediction: String?
    let mlConfidence: Double?
}

// 점수 데이터 구조체
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

// 세부 측정 데이터 구조체
struct ScoreDetailData {
    let avgYaw: Float
    let avgEAR: Float
    let eyeClosedRatio: Float
    let blinkCount: Int
    let yawScore: Float
    let eyeOpenScore: Float
    let eyeClosedScore: Float
    let blinkScore: Float

    let avgYawChange: Float?
    let snoozeRatio: Float?
    let totalFrames: Int?
    let blinkCountAux: Int?
    let yawStabilityScore: Float?
    let mlSnoozeScore: Float?
    let blinkScoreAux: Float?
}

// 세션 전체 데이터
struct SessionData {
    let startTime: Date
    let endTime: Date
    let totalDuration: TimeInterval
    let totalFocusTime: Int
    let averageScore: Float
    let scoreHistory: [ScoreData]
    let focusSegments: [(start: Date, end: Date)]
}
