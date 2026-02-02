//
//  FieldState.swift
//  rich
//
//  Created by 山下泰河 on 2026/02/01.
//

import Foundation

/// 場の状態を管理する構造体
struct FieldState {
    var lastPlayedCards: [Card] = []          // 最後に出されたカードグループ
    var isRevolution: Bool = false            // 革命状態（永続）
    var isElevenBackActive: Bool = false      // 11バック状態（場が流れるまで）
    var suitLock: Suit? = nil                 // 記号縛り
    var sequenceLock: SequenceLock? = nil     // 階段縛り
    var lastPlayedPlayerIndex: Int? = nil     // 最後にカードを出したプレイヤーのインデックス
    
    /// 階段縛りの情報
    struct SequenceLock {
        let startRank: Rank    // 現在のランク
        let count: Int         // 出されたカード枚数
        let isAscending: Bool  // 昇順か降順か
    }
    
    /// 場をリセット
    mutating func reset() {
        lastPlayedCards = []
        isElevenBackActive = false
        suitLock = nil
        sequenceLock = nil
        lastPlayedPlayerIndex = nil
        // 革命状態は維持
    }
    
    /// 場に出されている枚数
    var lastPlayedCount: Int {
        lastPlayedCards.count
    }
    
    /// 場に出されているランク（単一ランクの場合）
    var lastPlayedRank: Rank? {
        guard !lastPlayedCards.isEmpty else { return nil }
        let ranks = Set(lastPlayedCards.map { $0.rank })
        return ranks.count == 1 ? ranks.first : nil
    }
    
    /// 場が空かどうか
    var isEmpty: Bool {
        lastPlayedCards.isEmpty
    }
    
    /// 代替：discardPile（互換性のため）
    var discardPile: [Card] {
        get { lastPlayedCards }
        set { lastPlayedCards = newValue }
    }
}
