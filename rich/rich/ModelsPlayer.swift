//
//  Player.swift
//  rich
//
//  Created by 山下泰河 on 2026/02/01.
//

import Foundation

/// プレイヤーの役職（人狼要素）
enum Role {
    case wolf    // 人狼
    case citizen // 市民
}

/// プレイヤー
struct Player: Identifiable {
    let id = UUID()
    var name: String
    var hand: [Card]
    var isFinished: Bool // 手札を全て出し切ったか
    var role: Role
    
    init(name: String) {
        self.name = name
        self.hand = []
        self.isFinished = false
        self.role = .citizen // デフォルトは市民
    }
}
