//
//  Card.swift
//  rich
//
//  Created by 山下泰河 on 2026/02/01.
//

import Foundation

/// トランプのスート
enum Suit: String, CaseIterable {
    case spade = "♠︎"
    case heart = "♥︎"
    case diamond = "♦︎"
    case club = "♣︎"
    case joker = "🃏"
}

/// トランプのランク
/// 大富豪では 3 が最弱、2 が最強
enum Rank: Int, CaseIterable {
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9
    case ten = 10
    case jack = 11
    case queen = 12
    case king = 13
    case ace = 14
    case two = 15
    case joker = 99 // ジョーカー専用値
}

/// トランプカード
struct Card: Identifiable, Equatable {
    let id = UUID()
    let suit: Suit
    let rank: Rank
    
    /// ジョーカー生成用イニシャライザ
    static func joker() -> Card {
        Card(suit: .joker, rank: .joker)
    }
    
    /// 通常カード判定
    var isJoker: Bool {
        suit == .joker && rank == .joker
    }
}
