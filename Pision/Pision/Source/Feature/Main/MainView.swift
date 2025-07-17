//
//  MainView.swift
//  Pision
//
//  Created by 여성일 on 7/14/25.
//

import SwiftUI

struct MainView: View {
    @State private var showRecord = false
    @State private var showAnalyzeList = false
    @State private var showSetting = false
}

extension MainView {
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.clear.ignoresSafeArea()
      VStack {
        Text("당신의 집중을 분석해 보세요")
          .font(.title)
        Spacer()
        VStack {
          Button {
            showRecord = true
          } label: {
            Text("시작")
              .foregroundStyle(.white)
              .frame(width: 150, height: 150)
              .background(.black)
              .clipShape(.circle)
          }
          .buttonStyle(.plain)
          bottomButtonView
        }
        Spacer()
      }
    }
    .padding(.horizontal, 16)
    .navigationDestination(isPresented: $showRecord) {
      RecordView()
    }
    .navigationDestination(isPresented: $showAnalyzeList) {
      AnalyzeListView()
    }
    .navigationDestination(isPresented: $showSetting) {
      CriteriaSettingView()
    }
  }
  
  private var bottomButtonView: some View {
    HStack {
      Button {
        showAnalyzeList = true
      } label: {
        Text("기록")
          .foregroundStyle(.white)
          .frame(width: 100, height: 100)
          .background(.black)
          .clipShape(.circle)
      }
      .buttonStyle(.plain)
      Spacer()
      Button {
        showSetting = true
      } label: {
        Text("설정")
          .foregroundStyle(.white)
          .frame(width: 100, height: 100)
          .background(.black)
          .clipShape(.circle)
      }
      .buttonStyle(.plain)
    }
  }
}

#Preview {
  MainView()
}
