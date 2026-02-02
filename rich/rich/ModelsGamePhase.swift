//
//  GamePhase.swift
//  rich
//
//  Created by 山下泰河 on 2026/02/01.
//

import Foundation

/// ゲーム全体の進行フェーズ
/// 後続実装で各フェーズ固有のロジックを追加する
enum GamePhase {
    case lobby      // ロビー待機
    case dealing    // カード配布中
    case playing    // 大富豪プレイ中
    case wolfAction // 人狼アクション（未実装）
    case voting     // 投票フェーズ（未実装）
    case result     // 結果表示
}
