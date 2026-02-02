//
//  Deck.swift
//  rich
//
//  Created by 山下泰河 on 2026/02/01.
//

import Foundation

/// トランプデッキ（53枚: 通常52枚 + ジョーカー1枚）
struct Deck {
    private(set) var cards: [Card]
    
    /// 53枚のデッキを生成
    init() {
        var deck: [Card] = []
        
        // 通常カード52枚
        for suit in [Suit.spade, .heart, .diamond, .club] {
            for rank in Rank.allCases where rank != .joker {
                deck.append(Card(suit: suit, rank: rank))
            }
        }
        
        // ジョーカー1枚
        deck.append(Card.joker())
        
        self.cards = deck
    }
    
    /// デッキをシャッフル
    mutating func shuffle() {
        cards.shuffle()
    }
    
    /// カードを1枚引く
    /// - Returns: 引いたカード。デッキが空の場合は nil
    mutating func draw() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }
    
    /// 残りのカード枚数
    var count: Int {
        cards.count
    }
}
