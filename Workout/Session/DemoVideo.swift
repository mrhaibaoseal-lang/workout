import SwiftUI
import WebKit

/// 動作示範影片（0.33.0）：使用者不會健身、看不出自己畫的骨架對不對，所以動作卡多一個「看影片」。
/// - 精選的動作：嵌入官方 YouTube 播放器（youtube-nocookie，App 裡直接播）。
///   挑片原則：中文教練頻道、標題明確是這個動作的教學；只靠標題、頻道、說明欄判斷，沒把握的不放。
/// - 其他動作：「在 YouTube 搜尋示範」，用動作名＋「正確姿勢 教學」搜尋。
/// - 影片失效、作者關閉嵌入或沒網路：播放器下面一直有「在 YouTube 開啟」，骨架動畫也還在動作卡上。
struct DemoVideo: Equatable {
    let id: String
    /// 頻道或系列名（顯示用）
    let source: String
}

enum DemoVideos {
    /// 動作 → 影片。2026-11-22 用標題、頻道挑的；使用者回報不能播或不對就換掉。
    static let byExercise: [String: DemoVideo] = [
        "db_bench": DemoVideo(id: "Mft7qhR15e4", source: "GYMEFIT 動作教室"),
        "db_neutral_press": DemoVideo(id: "Mft7qhR15e4", source: "GYMEFIT 動作教室"),
        "db_incline_press": DemoVideo(id: "eM0XATpUn0Y", source: "GYMEFIT 動作教室"),
        "db_floor_press": DemoVideo(id: "-U2iif9yPY4", source: "Erica & Euphe 教練"),
        "db_shoulder_press": DemoVideo(id: "Mod-Xpf4G1Q", source: "GYMEFIT 動作教室"),
        "db_row": DemoVideo(id: "F8sOrYE495E", source: "GYMEFIT 動作教室"),
        "pushup": DemoVideo(id: "i17dhEn4_7Y", source: "新手訓練教室"),
        "goblet_squat": DemoVideo(id: "Jb3pTR5O8Yg", source: "練健康 動作資料庫"),
        "db_squat": DemoVideo(id: "Jb3pTR5O8Yg", source: "練健康 動作資料庫"),
        "heel_goblet": DemoVideo(id: "Jb3pTR5O8Yg", source: "練健康 動作資料庫"),
        "goblet_15": DemoVideo(id: "Jb3pTR5O8Yg", source: "練健康 動作資料庫"),
        "db_rdl": DemoVideo(id: "5u_hQA-r4yk", source: "啞鈴 RDL 完整教學"),
        "db_sl_rdl": DemoVideo(id: "TXZtkcs7mlY", source: "GYMEFIT 動作教室"),
        "sl_rdl": DemoVideo(id: "TXZtkcs7mlY", source: "GYMEFIT 動作教室"),
        "db_split_squat": DemoVideo(id: "XPmdrYz50gA", source: "GYMEFIT 動作教室"),
        "split_squat": DemoVideo(id: "XPmdrYz50gA", source: "GYMEFIT 動作教室"),
        "bb_hip_thrust": DemoVideo(id: "EkvccRWyqo0", source: "槓鈴臀推入門"),
        "db_hip_thrust": DemoVideo(id: "EkvccRWyqo0", source: "槓鈴臀推入門"),
        "db_curl": DemoVideo(id: "2g4v5qv8ByM", source: "卓叔增重"),
        "db_hammer_curl": DemoVideo(id: "jxeKeQ6NgpI", source: "健身啊 動作教學"),
        "db_incline_curl": DemoVideo(id: "7qSoY2rA6uY", source: "上斜啞鈴彎舉教學"),
        "cable_pulldown": DemoVideo(id: "Y_GzVrZtKhE", source: "健身房動作教學"),
        "cable_close_pulldown": DemoVideo(id: "Y_GzVrZtKhE", source: "健身房動作教學"),
        "cable_straight_arm": DemoVideo(id: "1ci_F-HA_cQ", source: "i運動 教練一對一"),
        "cable_pushdown": DemoVideo(id: "TowYmb7YWhA", source: "三頭繩索下拉教學"),
        "db_overhead_ext": DemoVideo(id: "99Wrh_GR26k", source: "坐姿啞鈴三頭屈伸"),
        "db_skull": DemoVideo(id: "_zo9fbuqI9w", source: "Fun Sport 趣運動"),
        "db_lateral": DemoVideo(id: "Vil5b7fXqWs", source: "ATTACUS 重訓教學"),
        "db_lean_lateral": DemoVideo(id: "Vil5b7fXqWs", source: "ATTACUS 重訓教學"),
        "db_rear_fly": DemoVideo(id: "CdivnPOYCJQ", source: "反向飛鳥 後三角"),
        "db_chest_rear_fly": DemoVideo(id: "CdivnPOYCJQ", source: "反向飛鳥 後三角"),
        "dead_bug": DemoVideo(id: "Afa89jCoKuw", source: "死蟲式完整教學"),
    ]

    /// 進階版沿用原本動作的影片（動作一樣，只是更慢或停頓）
    static let sameAs: [String: String] = [
        "pause_pushup": "pushup", "pause_split_squat": "split_squat",
    ]

    static func video(for ex: Exercise) -> DemoVideo? {
        byExercise[ex.id] ?? sameAs[ex.id].flatMap { byExercise[$0] }
    }

    static func watchURL(_ v: DemoVideo) -> URL {
        URL(string: "https://www.youtube.com/watch?v=\(v.id)")!
    }

    static func searchURL(for ex: Exercise) -> URL {
        var c = URLComponents(string: "https://www.youtube.com/results")!
        c.queryItems = [URLQueryItem(name: "search_query", value: "\(ex.name) 正確姿勢 教學")]
        return c.url!
    }

    /// 只接受 YouTube 影片 ID 的字元，避免組 HTML 時出錯
    static func isValidId(_ id: String) -> Bool {
        id.count == 11 && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}

/// 官方 YouTube 嵌入播放器。用 HTML iframe 載入，並給一個 https 的 baseURL，YouTube 才會接受嵌入。
struct YouTubePlayer: UIViewRepresentable {
    let video: DemoVideo

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        load(web)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    private func load(_ web: WKWebView) {
        guard DemoVideos.isValidId(video.id) else { return }
        let src = "https://www.youtube-nocookie.com/embed/\(video.id)?playsinline=1&rel=0&modestbranding=1"
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;background:#000;height:100%}iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style>
        </head><body><iframe src="\(src)" referrerpolicy="strict-origin-when-cross-origin"
        allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://com.mrhaibaoseal.workout"))
    }
}

/// 動作卡「看影片」打開的畫面。
struct DemoVideoSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let v = DemoVideos.video(for: exercise) {
                        YouTubePlayer(video: v)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("來源：\(v.source)（YouTube）")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Button {
                            openURL(DemoVideos.watchURL(v))
                        } label: {
                            Label("在 YouTube 開啟", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GhostButtonStyle())
                        Text("播不出來（沒網路、影片下架）時按上面的按鈕，或照動作卡上的動畫做。")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    } else {
                        Text("這個動作還沒有精選影片。")
                            .font(.subheadline)
                            .foregroundStyle(Theme.fg)
                        Button {
                            openURL(DemoVideos.searchURL(for: exercise))
                        } label: {
                            Label("在 YouTube 搜尋「\(exercise.name)」示範", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(HotButtonStyle())
                        Text("挑有教練或物理治療師、側面拍得清楚、會講常見錯誤的影片。")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("重點").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                        Text(exercise.tip).font(.subheadline).foregroundStyle(Theme.fg)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}
