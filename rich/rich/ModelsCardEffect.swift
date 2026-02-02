//
//  CardEffect.swift
//  rich
//
//  Created by 山下泰河 on 2026/02/01.
//

import Foundation

/// カードの特殊効果
enum CardEffect {
    case none           // 効果なし
    case eight          // 8ギリ（場を流す）
    case skip(Int)      // 5スキップ（枚数分スキップ）
    case pass(Int)      // 7渡し（枚数分カードを渡す）
    case discard(Int)   // 10捨て（枚数分カードを捨てる）
    case elevenBack     // 11バック（場が流れるまで強さ反転）
    case revolution     // 革命（4枚以上の同ランク出し）
    
    /// ランクから効果を判定
    static func from(rank: Rank, count: Int) -> CardEffect {
        switch rank {
        case .eight:
            return .eight
        case .five:
            return .skip(count)
        case .seven:
            return .pass(count)
        case .ten:
            return .discard(count)
        case .jack:
            return .elevenBack
        default:
            // 4枚以上の同ランク出しは革命
            if count >= 4 {
                return .revolution
            }
            return .none
        }
    }
}
