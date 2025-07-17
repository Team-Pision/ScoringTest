//
//  Float+Average.swift
//  Pision
//
//  Created by rundo on 7/16/25.
//

import Foundation

extension Array where Element == Float {
    func average() -> Float {
        guard !isEmpty else { return 0 }
        return self.reduce(0, +) / Float(self.count)
    }
}
