//
//  ContentView.swift
//  rich
//
//  Created by 山下泰河 on 2026/02/01.
//

import SwiftUI

/// フェーズ1: 大富豪ゲーム画面
/// ロジック確認用の最小限UI
struct ContentView: View {
    @State private var gameState = GameState()
    @State private var playerName = ""
    @State private var selectedCards: Set<UUID> = []
    
    // 現在のプレイヤーの手札で出せるカードID集合（Viewは結果だけ参照）
    private var playableIDs: Set<UUID> {
        if let player = gameState.currentPlayer {
            return gameState.playableCardIDs(for: player)
        }
        return []
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // フェーズ表示
            Text("Phase: \(phaseText)")
                .font(.headline)
            
            // ロビー画面
            if gameState.phase == .lobby {
                lobbyView
            }
            
            // プレイ中画面
            if gameState.phase == .playing {
                playingView
            }
            
            // 結果画面
            if gameState.phase == .result {
                resultView
            }
        }
        .padding()
    }
    
    // MARK: - Lobby View
    
    private var lobbyView: some View {
        VStack(spacing: 16) {
            Text("Players: \(gameState.players.count)/5")
            
            // プレイヤーリスト
            ForEach(gameState.players) { player in
                HStack {
                    Text(player.name)
                    Spacer()
                    Button("Remove") {
                        gameState.removePlayer(id: player.id)
                    }
                }
            }
            
            // プレイヤー追加
            HStack {
                TextField("Player Name", text: $playerName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    guard !playerName.isEmpty else { return }
                    gameState.addPlayer(name: playerName)
                    playerName = ""
                }
                .disabled(gameState.players.count >= 5)
            }
            
            // ゲーム開始
            Button("Start Game") {
                gameState.startGame()
            }
            .disabled(!gameState.canStartGame)
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Playing View
    
    private var playingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 場の情報
                fieldInfoView
                
                // プレイヤー一覧
                playersListView
                
                // 現在のプレイヤーの手札
                if let currentPlayer = gameState.currentPlayer {
                    currentPlayerHandView(player: currentPlayer)
                }
                
                // 特殊効果処理
                if gameState.pendingEffect != nil {
                    specialEffectView
                }
            }
        }
    }
    
    // MARK: - Field Info View
    
    private var fieldInfoView: some View {
        VStack(spacing: 8) {
            Text("場の状態")
                .font(.headline)
            
            HStack {
                Text("革命: \(gameState.fieldState.isRevolution ? "ON" : "OFF")")
                Text("11バック: \(gameState.fieldState.isElevenBackActive ? "ON" : "OFF")")
            }
            .font(.caption)
            
            if let suitLock = gameState.fieldState.suitLock {
                Text("記号縛り: \(suitLock.rawValue)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if gameState.fieldState.sequenceLock != nil {
                Text("階段縛り: ON")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Text("場のカード: \(gameState.fieldState.lastPlayedCards.count)枚")
                .font(.caption)
            
            // 場のカード表示
            if !gameState.fieldState.lastPlayedCards.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(gameState.fieldState.lastPlayedCards) { card in
                            CardView(card: card, isSelected: false, isPlayable: true)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Players List View
    
    private var playersListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プレイヤー一覧")
                .font(.headline)
            
            ForEach(Array(gameState.players.enumerated()), id: \.element.id) { index, player in
                HStack {
                    if index == gameState.currentPlayerIndex {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text(player.name)
                        .fontWeight(index == gameState.currentPlayerIndex ? .bold : .regular)
                    
                    Spacer()
                    
                    Text("\(player.hand.count)枚")
                        .font(.caption)
                    
                    if player.isFinished {
                        Text("上がり")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Current Player Hand View
    
    private func currentPlayerHandView(player: Player) -> some View {
        VStack(spacing: 12) {
            Text("\(player.name)の手札")
                .font(.headline)
            
            // 手札表示
            ScrollView(.horizontal) {
                HStack {
                    ForEach(player.hand) { card in
                        CardView(
                            card: card,
                            isSelected: selectedCards.contains(card.id),
                            isPlayable: playableIDs.contains(card.id)
                        )
                        .onTapGesture {
                            // 出せないカードはタップ無効
                            guard playableIDs.contains(card.id) else { return }
                            toggleCardSelection(card.id)
                        }
                    }
                }
            }
            
            // Viewはプレイ可否ロジックを持たず、GameStateの結果のみ参照
            // アクションボタン
            HStack(spacing: 16) {
                Button("カードを出す") {
                    playSelectedCards()
                }
                .disabled(selectedCards.isEmpty || !canPlaySelected())
                .buttonStyle(.borderedProminent)
                
                Button("パス") {
                    gameState.pass()
                }
                .buttonStyle(.bordered)
                
                Button("選択解除") {
                    selectedCards.removeAll()
                }
                .buttonStyle(.bordered)
                .disabled(selectedCards.isEmpty)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Special Effect View
    
    private var specialEffectView: some View {
        VStack(spacing: 12) {
            if case .pass(let count) = gameState.pendingEffect {
                Text("7渡し: \(count)枚のカードを選択して渡してください")
                    .font(.headline)
                
                Button("渡す") {
                    let cards = selectedCardsArray()
                    gameState.selectCardsToPass(cards)
                    selectedCards.removeAll()
                }
                .disabled(selectedCards.count != count)
                .buttonStyle(.borderedProminent)
            }
            
            if case .discard(let count) = gameState.pendingEffect {
                Text("10捨て: \(count)枚のカードを選択して捨ててください")
                    .font(.headline)
                
                Button("捨てる") {
                    let cards = selectedCardsArray()
                    gameState.selectCardsToDiscard(cards)
                    selectedCards.removeAll()
                }
                .disabled(selectedCards.count != count)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.2))
        .cornerRadius(8)
    }
    
    // MARK: - Result View
    
    private var resultView: some View {
        VStack(spacing: 16) {
            Text("ゲーム終了")
                .font(.title)
            
            Text("結果")
                .font(.headline)
            
            ForEach(Array(gameState.players.enumerated()), id: \.element.id) { index, player in
                HStack {
                    Text("\(index + 1). \(player.name)")
                    Spacer()
                    if player.isFinished {
                        Text("上がり")
                            .foregroundColor(.green)
                    } else {
                        Text("負け")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Button("ロビーに戻る") {
                gameState.returnToLobby()
                selectedCards.removeAll()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var phaseText: String {
        switch gameState.phase {
        case .lobby: return "Lobby"
        case .dealing: return "Dealing"
        case .playing: return "Playing"
        case .wolfAction: return "Wolf Action"
        case .voting: return "Voting"
        case .result: return "Result"
        }
    }
    
    private func toggleCardSelection(_ cardId: UUID) {
        if selectedCards.contains(cardId) {
            selectedCards.remove(cardId)
        } else {
            selectedCards.insert(cardId)
        }
    }
    
    private func selectedCardsArray() -> [Card] {
        guard let player = gameState.currentPlayer else { return [] }
        return player.hand.filter { selectedCards.contains($0.id) }
    }
    
    private func canPlaySelected() -> Bool {
        let cards = selectedCardsArray()
        return gameState.canPlayCards(cards)
    }
    
    private func playSelectedCards() {
        let cards = selectedCardsArray()
        guard !cards.isEmpty else { return }
        
        gameState.playCards(cards)
        selectedCards.removeAll()
    }
}

// MARK: - Card View

struct CardView: View {
    let card: Card
    let isSelected: Bool
    let isPlayable: Bool
    
    var body: some View {
        VStack {
            Text(card.suit.rawValue)
                .font(.title2)
            Text(rankText)
                .font(.caption)
        }
        .frame(width: 60, height: 80)
        .background(
            isSelected ? Color.yellow : (isPlayable ? Color.white : Color.gray.opacity(0.2))
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPlayable ? Color.blue : Color.black.opacity(0.3), lineWidth: isPlayable ? 2 : 1)
        )
        .opacity(isPlayable ? 1.0 : 0.6)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
    
    private var rankText: String {
        switch card.rank {
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        case .two: return "2"
        case .joker: return "JK"
        }
    }
}

#Preview {
    ContentView()
}

