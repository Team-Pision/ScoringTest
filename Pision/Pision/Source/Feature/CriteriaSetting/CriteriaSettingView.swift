//
//  CriteriaSettingView.swift
//  Pision
//
//  Created by 여성일 on 7/14/25.
//

import SwiftUI

struct CriteriaSettingView: View {
  @State private var isSleepyOn = false
  @State private var isEyeTrackingOn = false
  @State private var isPostureOn = false
  @State private var isGazeOn = false
  
  var body: some View {
    VStack() { // 뷰 전체 싸기
      // 토글 항목 박스
      VStack(spacing: 12) {
        Toggle("졸음 측정", isOn: $isSleepyOn)
        Divider()
        Toggle("눈동자 측정", isOn: $isEyeTrackingOn)
        Divider()
        Toggle("자세 측정", isOn: $isPostureOn)
        Divider()
        Toggle("시선 측정", isOn: $isGazeOn)
      }
      .padding(16)
      .background(Color(.systemGray5))
      .cornerRadius(12)
      
      Spacer()
      
      Button(action: {
        print("커스텀 수정 저장하기")
      }) {
        Text("저장")
          .frame(maxWidth: .infinity)
          .padding(12)
          .background(Color(.systemGray4))
          .cornerRadius(12)
      }
    }
    .padding(12)
  }
}

#Preview {
  CriteriaSettingView()
}
