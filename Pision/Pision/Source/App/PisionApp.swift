//
//  PisionApp.swift
//  Pision
//
//  Created by 여성일 on 7/14/25.
//

import SwiftUI

@main
struct PisionApp: App {
  var body: some Scene {
    WindowGroup {
      NavigationStack {
        MainView()
          .preferredColorScheme(.light) // 라이트모드로 일단 고정
      }
    }
  }
}
