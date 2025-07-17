//
//  AnalyzeListView.swift
//  Pision
//
//  Created by 여성일 on 7/14/25.
//

import SwiftUI

struct AnalyzeListView: View {
  
  var records: [Record] = sampleRecords
  
  var body: some View {
    VStack{
      // 집중 기록 타이틀
      HStack {
        Text("집중 기록")
          .font(.title)
      }
      ScrollView { // 리스트 스크롤
        VStack(spacing: 12) { // 리스트 전체
          ForEach(records) { record in
            NavigationLink(destination: AnalyzeView()) {
              RecordCardView(record: record)
            }
          }
        }
        .padding(16)
      }
    }
  }
}

struct RecordCardView: View {
  let record: Record
  
  var body: some View {
    HStack {
      VStack(spacing: 4) { // 날짜와 순공시간
        Text(record.date)
        
        Text(record.focusTime)
      }

      Spacer()
      
      VStack { // 리스트 클릭 버튼
        Button(action: {
          print("상세 분석으로 들어가기!")
        }) {
          Image(systemName: "arrowshape.right.circle")
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.gray)
    .cornerRadius(12)
  }
}

#Preview {
  AnalyzeListView()
}
