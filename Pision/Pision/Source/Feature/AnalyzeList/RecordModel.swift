//
//  AnalyzeMock.swift
//  Pision
//
//  Created by rundo on 7/15/25.
//

import Foundation

struct Record: Identifiable {
  let id = UUID()
  let date: String
  let focusTime: String
}

let sampleRecords: [Record] = [
  Record(date: "2025년 3월 14일", focusTime: "순공시간 3시간"),
  Record(date: "2025/6/8", focusTime: "2시간 7분"),
  Record(date: "2025/6/9", focusTime: "4시간 6분"),
  Record(date: "2025/6/10", focusTime: "2시간 8분"),
  Record(date: "2025/6/13", focusTime: "23시간 6분"),
  Record(date: "2025/6/23", focusTime: "2시간 45분"),
  Record(date: "2025/6/23", focusTime: "2시간 22분")
]
