//
//  GameLogic.swift
//  rich
//
//  Created by 山下泰河 on 2026/02/01.
//

import Foundation

/// 大富豪のゲームロジック（純粋関数集）
enum GameLogic {
    
    // MARK: - Card Comparison
    
    /// カードの強さを比較
    /// - Parameters:
    ///   - card: 比較対象のカード
    ///   - fieldCard: 場のカード
    ///   - isRevolution: 革命状態
    ///   - isElevenBack: 11バック状態
    /// - Returns: card が fieldCard より強い場合 true
    static func isStronger(
        card: Card,
        than fieldCard: Card,
        isRevolution: Bool,
        isElevenBack: Bool
    ) -> Bool {
        // ジョーカーは常に最強
        if card.isJoker { return true }
        if fieldCard.isJoker { return false }
        
        // 革命と11バックの状態を考慮
        let shouldReverse = isRevolution != isElevenBack // XOR
        
        if shouldReverse {
            return card.rank.rawValue < fieldCard.rank.rawValue
        } else {
            return card.rank.rawValue > fieldCard.rank.rawValue
        }
    }
    
    /// 複数枚のカードが場のカードより強いか判定
    static func canBeat(
        cards: [Card],
        fieldCards: [Card],
        isRevolution: Bool,
        isElevenBack: Bool
    ) -> Bool {
        guard !cards.isEmpty, !fieldCards.isEmpty else { return false }
        
        // ジョーカーが含まれている場合は常に勝てる
        if cards.contains(where: { $0.isJoker }) { return true }
        
        // 場のカードにジョーカーがある場合は負ける
        if fieldCards.contains(where: { $0.isJoker }) { return false }
        
        // 代表カードで比較
        let representativeCard = cards.first!
        let fieldRepresentativeCard = fieldCards.first!
        
        return isStronger(
            card: representativeCard,
            than: fieldRepresentativeCard,
            isRevolution: isRevolution,
            isElevenBack: isElevenBack
        )
    }
    
    // MARK: - Play Validation
    
    /// カードを出せるか判定
    static func canPlay(
        cards: [Card],
        fieldState: FieldState
    ) -> Bool {
        guard !cards.isEmpty else { return false }
        
        // 同じランクかチェック
        let ranks = Set(cards.map { $0.rank })
        guard ranks.count == 1 else { return false }
        
        // 場が空の場合は出せる
        if fieldState.isEmpty {
            return true
        }
        
        // 枚数が一致するかチェック
        guard cards.count == fieldState.lastPlayedCount else { return false }
        
        // 記号縛りチェック
        if let suitLock = fieldState.suitLock {
            let hasMatchingSuit = cards.allSatisfy { $0.suit == suitLock || $0.isJoker }
            guard hasMatchingSuit else { return false }
        }
        
        // 階段縛りチェック
        if let sequenceLock = fieldState.sequenceLock {
            guard canPlayWithSequenceLock(
                cards: cards,
                sequenceLock: sequenceLock,
                isRevolution: fieldState.isRevolution,
                isElevenBack: fieldState.isElevenBackActive
            ) else { return false }
        }
        
        // 強さチェック
        return canBeat(
            cards: cards,
            fieldCards: fieldState.lastPlayedCards,
            isRevolution: fieldState.isRevolution,
            isElevenBack: fieldState.isElevenBackActive
        )
    }
    
    /// 階段縛り時に出せるか判定
    private static func canPlayWithSequenceLock(
        cards: [Card],
        sequenceLock: FieldState.SequenceLock,
        isRevolution: Bool,
        isElevenBack: Bool
    ) -> Bool {
        guard cards.count == sequenceLock.count else { return false }
        guard let cardRank = cards.first?.rank else { return false }
        
        // ジョーカーは階段縛りを無視できる
        if cards.contains(where: { $0.isJoker }) { return true }
        
        // 革命・11バック状態を考慮
        let shouldReverse = isRevolution != isElevenBack
        
        // 期待されるランク値
        let expectedRankValue: Int
        if shouldReverse {
            expectedRankValue = sequenceLock.startRank.rawValue - 1
        } else {
            expectedRankValue = sequenceLock.startRank.rawValue + 1
        }
        
        return cardRank.rawValue == expectedRankValue
    }
    
    // MARK: - Lock Detection
    
    /// 記号縛りが発生するか判定
    /// 仕様:
    /// - 場が空の場合（1枚目のカード）: 縛りなし
    /// - 場に2枚目以降のカードが出された場合: スートが一致すれば縛り発生
    /// - 単一スート: A♣️4 → B♣️5 → ♣️縛り
    /// - 複数スート完全一致: A♣️♥️6,6 → B♣️♥️10,10 → ♣️縛り
    /// - 複数スート部分一致: A♣️♥️6,6 → B♣️♠️10,10 → ♣️縛り
    static func detectSuitLock(
        newCards: [Card],
        fieldState: FieldState
    ) -> Suit? {
        // 記号縛り修正: 場に2枚目以降のカードが出された時のみ、直前スート一致で縛りを発生させる
        // 場が空の場合（1枚目のカード）: 縛りなし
        guard !fieldState.isEmpty else { return nil }

        // 新しく出されたカードからジョーカー以外のスート集合を取得
        let newNonJokerSuits = Set(newCards.filter { !$0.isJoker }.map { $0.suit })
        // 直前に出されたカード（場のカード）からジョーカー以外のスート集合を取得
        let fieldNonJokerSuits = Set(fieldState.lastPlayedCards.filter { !$0.isJoker }.map { $0.suit })

        // いずれかがジョーカーのみ、または複数スートを含む場合は縛りなし
        guard newNonJokerSuits.count == 1, fieldNonJokerSuits.count == 1 else {
            return nil
        }

        // 直前と同じスートであれば記号縛り成立
        if newNonJokerSuits == fieldNonJokerSuits, let suit = newNonJokerSuits.first {
            return suit
        }

        return nil
    }
    
    /// 階段縛り（数字縛り）が発生するか判定
    /// 例：4を出した後に5が出たら、次は6を出さなければならない
    static func detectSequenceLock(
        newCards: [Card],
        fieldState: FieldState,
        isRevolution: Bool,
        isElevenBack: Bool
    ) -> FieldState.SequenceLock? {
        // 場が空の場合は縛りなし
        guard !fieldState.isEmpty else { return nil }
        
        // 既に階段縛りがある場合
        if let existingLock = fieldState.sequenceLock {
            // 連続しているか確認
            guard let newRank = newCards.first?.rank else { return nil }
            guard !newCards.contains(where: { $0.isJoker }) else { return nil }
            
            let shouldReverse = isRevolution != isElevenBack
            let expectedRankValue = shouldReverse ?
                existingLock.startRank.rawValue - 1 :
                existingLock.startRank.rawValue + 1
            
            if newRank.rawValue == expectedRankValue {
                // 階段縛り継続
                return FieldState.SequenceLock(
                    startRank: newRank,
                    count: newCards.count,
                    isAscending: !shouldReverse
                )
            } else {
                // 階段が途切れた（縛り解除）
                return nil
            }
        }
        
        // 新たに階段縛りが発生するかチェック
        guard let fieldRank = fieldState.lastPlayedRank else { return nil }
        guard let newRank = newCards.first?.rank else { return nil }
        
        // ジョーカーは階段縛り判定に含めない
        guard !newCards.contains(where: { $0.isJoker }) else { return nil }
        guard !fieldState.lastPlayedCards.contains(where: { $0.isJoker }) else { return nil }
        
        // 枚数が一致する必要がある
        guard newCards.count == fieldState.lastPlayedCount else { return nil }
        
        // 革命・11バック状態を考慮
        let shouldReverse = isRevolution != isElevenBack
        
        // 連続しているか判定
        let expectedRankValue = shouldReverse ?
            fieldRank.rawValue - 1 : fieldRank.rawValue + 1
        
        if newRank.rawValue == expectedRankValue {
            return FieldState.SequenceLock(
                startRank: newRank,
                count: newCards.count,
                isAscending: !shouldReverse
            )
        }
        
        return nil
    }
}
