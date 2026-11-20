import Foundation
import ActivityKit

/// 休息倒數的 Live Activity（鎖定畫面＋動態島）。App 和小工具都要編譯這個型別。
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 休息結束的時間
        var end: Date
        /// 這次休息總秒數（畫進度條用）
        var total: Double
        /// 「啞鈴臥推 · 第 2 組」
        var next: String
        /// 「12.5 kg × 10」
        var detail: String
        /// 要換重量就寫一行，例如「換重量：每邊 2.5 + 1.25」
        var change: String?
    }

    /// 今天的課表名稱
    var day: String
}
