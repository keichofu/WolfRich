//
//  GameState.swift
//  rich
//
//  Created by 山下泰河 on 2026/02/01.
//

import Foundation
import Observation

/// ゲーム全体の状態管理
@Observable
class GameState {
    var players: [Player] = []
    var currentPlayerIndex: Int = 0
    var phase: GamePhase = .lobby
    var deck: Deck = Deck()
    
    // MARK: - Game State (Phase 1)
    
    var fieldState: FieldState = FieldState()
    var passCount: Int = 0  // 連続パス数
    var pendingEffect: CardEffect? = nil  // 保留中の特殊効果
    var cardsToPass: [Card] = []  // 7渡しで渡すカード
    var cardsToDiscard: [Card] = []  // 10捨てで捨てるカード
    var lastCardPlayerIndex: Int? = nil  // 最後にカードを出したプレイヤーのインデックス
    
    // MARK: - Highlight Playable Cards (View helper)
    
    /// ハイライト判定用ロジック: 現在のルール・場の状態に基づき、
    /// 引数プレイヤーの手札のうち「今この場で出せる可能性があるカード」のID集合を返す
    /// - Parameters:
    ///   - player: 判定対象のプレイヤー
    /// - Returns: 出せる可能性があるカードの `UUID` セット
    func playableCardIDs(for player: Player) -> Set<UUID> {
        // 場が空なら全カードが出せる
        if fieldState.isEmpty {
            return Set(player.hand.map { $0.id })
        }
        
        var result: Set<UUID> = []
        
        // ランクごとにまとめ、同ランクの1..n枚で出せる組み合わせがあるかを確認
        let groups = Dictionary(grouping: player.hand, by: { $0.rank })
        
        for (_, cardsOfSameRank) in groups {
            // 既に場に出されている枚数がある場合、その枚数に合わせる必要がある
            let requiredCount = fieldState.lastPlayedCount
            
            // 同ランクのカードを強さ順に（現状態に合わせて）並び替え
            let sorted = sortHand(cardsOfSameRank)
            
            // 1枚から最大枚数まで（ただし場が空でないので requiredCount に合わせる）
            let candidateCounts: [Int] = requiredCount > 0 ? [requiredCount] : Array(1...sorted.count)
            
            for count in candidateCounts {
                guard count <= sorted.count else { continue }
                let testCards = Array(sorted.prefix(count))
                if canPlayCards(testCards) {
                    // このランクは出せる。該当ランクの全カードをハイライト対象にするのではなく、
                    // 少なくとも出せる枚数分は可能性があるため、該当ランクのカードIDを追加
                    for c in cardsOfSameRank { result.insert(c.id) }
                    break
                }
            }
        }
        
        return result
    }
    
    init() {}
    
    // MARK: - Lobby Phase
    
    /// プレイヤーを追加（3〜5人まで）
    func addPlayer(name: String) {
        guard players.count < 5 else { return }
        let player = Player(name: name)
        players.append(player)
    }
    
    /// プレイヤーを削除
    func removePlayer(id: UUID) {
        players.removeAll { $0.id == id }
    }
    
    /// ゲーム開始可能判定
    var canStartGame: Bool {
        players.count >= 3 && players.count <= 5
    }
    
    // MARK: - Phase Transition
    
    /// ゲーム開始（lobby → dealing）
    func startGame() {
        guard canStartGame else { return }
        phase = .dealing
        dealCards()
    }
    
    /// カード配布処理
    private func dealCards() {
        deck = Deck()
        deck.shuffle()
        
        // 状態リセット
        fieldState = FieldState()
        passCount = 0
        pendingEffect = nil
        cardsToPass = []
        cardsToDiscard = []
        lastCardPlayerIndex = nil
        
        // 全プレイヤーの手札をリセット
        for index in players.indices {
            players[index].hand = []
            players[index].isFinished = false
        }
        
        // 均等配布
        let baseCount = deck.count / players.count
        let remainder = deck.count % players.count
        
        for (index, _) in players.enumerated() {
            // 基本枚数
            for _ in 0..<baseCount {
                if let card = deck.draw() {
                    players[index].hand.append(card)
                }
            }
        }
        
        // 余りカードをランダムに配布
        for _ in 0..<remainder {
            let randomIndex = Int.random(in: 0..<players.count)
            if let card = deck.draw() {
                players[randomIndex].hand.append(card)
            }
        }
        
        // 手札を強さ順にソート（初期は通常状態）
        sortAllPlayersHands()
        
        // 配布完了後、プレイフェーズへ
        phase = .playing
    }
    
    /// 全プレイヤーの手札を現在の状態に応じてソート
    private func sortAllPlayersHands() {
        for index in players.indices {
            players[index].hand = sortHand(players[index].hand)
        }
    }
    
    /// 手札を強さ順にソート（強い順）
    private func sortHand(_ hand: [Card]) -> [Card] {
        return hand.sorted { card1, card2 in
            // ジョーカーは常に最強
            if card1.isJoker { return true }
            if card2.isJoker { return false }
            
            // 革命と11バックの状態を考慮
            let shouldReverse = fieldState.isRevolution != fieldState.isElevenBackActive
            
            if shouldReverse {
                // 反転状態：小さい方が強い
                return card1.rank.rawValue < card2.rank.rawValue
            } else {
                // 通常状態：大きい方が強い
                return card1.rank.rawValue > card2.rank.rawValue
            }
        }
    }
    
    // MARK: - Game Logic (Phase 1)
    
    /// 現在のプレイヤー
    var currentPlayer: Player? {
        guard players.indices.contains(currentPlayerIndex) else { return nil }
        return players[currentPlayerIndex]
    }
    
    /// カードを出せるか判定
    func canPlayCards(_ cards: [Card]) -> Bool {
        return GameLogic.canPlay(cards: cards, fieldState: fieldState)
    }
    
    /// ハイライト判定の単カード版（内部利用や将来拡張用）
    /// 特定のカードが現在出せるか判定（ハイライト表示用）
    func canPlayCard(_ card: Card, from player: Player) -> Bool {
        // 場が空の場合は全てのカードが出せる
        if fieldState.isEmpty {
            return true
        }
        
        // 同じランクのカードを全て抽出
        let sameRankCards = player.hand.filter { $0.rank == card.rank }
        
        // 1枚から最大枚数まで試す
        for count in 1...sameRankCards.count {
            let testCards = Array(sameRankCards.prefix(count))
            if canPlayCards(testCards) {
                return true
            }
        }
        
        return false
    }
    
    /// カードを場に出す
    func playCards(_ cards: [Card]) {
        guard let playerIndex = players.firstIndex(where: { $0.id == currentPlayer?.id }) else { return }
        
        // 手札から削除
        for card in cards {
            if let index = players[playerIndex].hand.firstIndex(where: { $0.id == card.id }) {
                players[playerIndex].hand.remove(at: index)
            }
        }
        
        // 場に追加（上書き）
        fieldState.lastPlayedCards = cards
        fieldState.lastPlayedPlayerIndex = playerIndex
        lastCardPlayerIndex = playerIndex
        
        // パスカウントリセット
        passCount = 0
        
        // 手札が0枚になったら上がり
        if players[playerIndex].hand.isEmpty {
            players[playerIndex].isFinished = true
            checkGameEnd()
            if phase == .result {
                return // ゲーム終了
            }
            // 上がったプレイヤーの次へ移動
            moveToNextPlayer()
            return
        }
        
        // 特殊効果判定
        let effect = CardEffect.from(rank: cards.first!.rank, count: cards.count)
        
        // 縛り判定（8ギリ以外）
        if case .eight = effect {
            // 8ギリの場合は縛り判定をスキップ
        } else {
            checkLocks(newCards: cards)
        }
        
        // 特殊効果適用と次プレイヤー移動
        applyEffectAndMove(effect)
    }
    
    /// 特殊効果を適用し、必要に応じて次のプレイヤーに移動
    private func applyEffectAndMove(_ effect: CardEffect) {
        switch effect {
        case .none:
            moveToNextPlayer()
            
        case .eight:
            // 8ギリ：場を流して同じプレイヤーが続ける
            resetField()
            // currentPlayerIndex はそのまま
            
        case .skip(let count):
            // 5スキップ：出した枚数分、次のプレイヤーをスキップ（自動パス扱い）
            // 重要: passCount には加算しない
            guard count > 0 else {
                moveToNextPlayer()
                return
            }
            var skipsRemaining = count
            // 連続して、上がっていないプレイヤーだけを数えてスキップ
            while skipsRemaining > 0 {
                moveToNextPlayerInternal()
                if !players[currentPlayerIndex].isFinished {
                    // 自動パス扱いだが passCount は増やさない仕様
                    skipsRemaining -= 1
                }
            }
            // スキップ後、次の有効プレイヤーにターンを進める
            moveToNextPlayerInternal()
            
        case .pass(let count):
            // 7渡し：後で処理するために保留（次のプレイヤーには移動しない）
            pendingEffect = .pass(count)
            
        case .discard(let count):
            // 10捨て：後で処理するために保留（次のプレイヤーには移動しない）
            pendingEffect = .discard(count)
            
        case .elevenBack:
            // 11バック：場が流れるまで強さ反転
            fieldState.isElevenBackActive = true
            // 手札を再ソート
            sortAllPlayersHands()
            moveToNextPlayer()
            
        case .revolution:
            // 革命：永続的に強さ反転（トグル）
            fieldState.isRevolution.toggle()
            // 手札を再ソート
            sortAllPlayersHands()
            moveToNextPlayer()
        }
    }
    
    /// パスする
    func pass() {
        passCount += 1
        
        // 最後にカードを出したプレイヤー以外が全員パスしたか確認
        checkAndResetField()
        
        // 場がリセットされていなければ次のプレイヤーへ
        if !fieldState.isEmpty {
            moveToNextPlayer()
        }
    }
    
    /// 最後にカードを出したプレイヤー以外が全員パスしたか確認し、必要なら場をリセット
    private func checkAndResetField() {
        let activePlayers = players.filter { !$0.isFinished }
        
        // 最後にカードを出したプレイヤー以外が全員パスしたら場をリセット
        // 判定条件: passCount >= activePlayers.count - 1
        if passCount >= activePlayers.count - 1 {
            resetField()
            
            // 最後にカードを出したプレイヤーに戻る
            if let lastPlayerIndex = lastCardPlayerIndex {
                currentPlayerIndex = lastPlayerIndex
            }
        }
    }
    

    
    /// 縛り判定
    private func checkLocks(newCards: [Card]) {
        // 記号縛り
        if let suitLock = GameLogic.detectSuitLock(newCards: newCards, fieldState: fieldState) {
            fieldState.suitLock = suitLock
        }
        
        // 階段縛り
        if let sequenceLock = GameLogic.detectSequenceLock(
            newCards: newCards,
            fieldState: fieldState,
            isRevolution: fieldState.isRevolution,
            isElevenBack: fieldState.isElevenBackActive
        ) {
            fieldState.sequenceLock = sequenceLock
        }
    }
    
    /// 場をリセット
    private func resetField() {
        // 11バックが有効だった場合、解除時に手札を再ソート
        let was11BackActive = fieldState.isElevenBackActive
        
        fieldState.reset()
        passCount = 0
        
        if was11BackActive {
            sortAllPlayersHands()
        }
    }
    
    /// 次のプレイヤーへ移動
    private func moveToNextPlayer() {
        moveToNextPlayerInternal()
    }
    
    /// 内部用：次のプレイヤーへ移動（上がっていないプレイヤーをスキップ）
    private func moveToNextPlayerInternal() {
        repeat {
            currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        } while players[currentPlayerIndex].isFinished
    }
    
    /// ゲーム終了判定
    private func checkGameEnd() {
        let activePlayers = players.filter { !$0.isFinished }
        
        // 1人を除いて全員上がったら終了
        if activePlayers.count <= 1 {
            phase = .result
        }
    }
    
    /// 7渡し：カードを選択
    func selectCardsToPass(_ cards: [Card]) {
        guard case .pass(let count) = pendingEffect else { return }
        guard cards.count == count else { return }
        
        // カードを手札から削除
        guard let playerIndex = players.firstIndex(where: { $0.id == currentPlayer?.id }) else { return }
        for card in cards {
            if let index = players[playerIndex].hand.firstIndex(where: { $0.id == card.id }) {
                players[playerIndex].hand.remove(at: index)
            }
        }
        
        // 次のプレイヤーに渡す
        let nextIndex = (currentPlayerIndex + 1) % players.count
        players[nextIndex].hand.append(contentsOf: cards)
        
        // 渡されたプレイヤーの手札を再ソート
        players[nextIndex].hand = sortHand(players[nextIndex].hand)
        
        // 効果をクリアして次のプレイヤーへ
        pendingEffect = nil
        moveToNextPlayer()
    }
    
    /// 10捨て：カードを選択
    func selectCardsToDiscard(_ cards: [Card]) {
        guard case .discard(let count) = pendingEffect else { return }
        guard cards.count == count else { return }
        
        // カードを手札から削除
        guard let playerIndex = players.firstIndex(where: { $0.id == currentPlayer?.id }) else { return }
        for card in cards {
            if let index = players[playerIndex].hand.firstIndex(where: { $0.id == card.id }) {
                players[playerIndex].hand.remove(at: index)
            }
        }
        
        // 効果をクリアして次のプレイヤーへ
        pendingEffect = nil
        moveToNextPlayer()
    }
    
    /// 7渡し・10捨てをスキップ
    func skipPendingEffect() {
        guard pendingEffect != nil else { return }
        
        // 効果をキャンセルして次のプレイヤーへ
        pendingEffect = nil
        moveToNextPlayer()
    }
    
    // MARK: - Phase Transition (Unused in Phase 1)
    
    /// プレイ中 → 人狼アクション（フェーズ1では未使用）
    func moveToWolfAction() {
        guard phase == .playing else { return }
        phase = .wolfAction
    }
    
    /// 人狼アクション → 投票（フェーズ1では未使用）
    func moveToVoting() {
        guard phase == .wolfAction else { return }
        phase = .voting
    }
    
    /// 投票 → 結果（フェーズ1では未使用）
    func moveToResult() {
        guard phase == .voting else { return }
        phase = .result
    }
    
    /// 結果 → ロビーへ戻る（再戦用）
    func returnToLobby() {
        guard phase == .result else { return }
        currentPlayerIndex = 0
        fieldState = FieldState()
        passCount = 0
        pendingEffect = nil
        cardsToPass = []
        cardsToDiscard = []
        lastCardPlayerIndex = nil
        phase = .lobby
    }
}

