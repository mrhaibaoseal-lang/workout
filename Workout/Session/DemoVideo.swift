import SwiftUI

/// 動作示範影片（0.33.0）：使用者不會健身、看不出自己畫的骨架對不對，所以動作卡多一個「看影片」。
/// - 精選的動作：開那支 YouTube 影片（0.46.0 起不再內嵌播放器，改成小按鈕交給 YouTube）。
///   挑片原則：中文教練頻道、標題明確是這個動作的教學；只靠標題、頻道、說明欄判斷，沒把握的不放。
/// - 其他動作：「在 YouTube 搜尋示範」，用動作名＋「正確姿勢 教學」搜尋。
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
        // 第二批動作共用相近動作的影片
        "db_deadlift": "db_rdl", "cable_one_arm_pushdown": "cable_pushdown",
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

    /// 只接受 YouTube 影片 ID 的字元，避免組網址時出錯
    static func isValidId(_ id: String) -> Bool {
        // 只收 ASCII：`isLetter`／`isNumber` 會放過中文字和全形數字
        id.count == 11 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}

/// 動作卡「動作說明」打開的畫面（0.46.0 起）：人物動畫為主，再來重點、肌群圖；YouTube 只剩動畫右下角一顆小按鈕。
struct DemoVideoSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var inventory: InventoryStore

    /// 示範動畫：穿使用者目前裝備的角色（減少動態效果時停在定格）
    private var demoStage: some View {
        CharacterStage(move: CharacterMove.forExercise(exercise), loadout: inventory.state.loadout,
                      animated: !reduceMotion, showStats: false)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(
                RadialGradient(
                    colors: [Color(gearHex: "#26303D"), Color(gearHex: "#141920"), Color(gearHex: "#0C0F14")],
                    center: .top, startRadius: 10, endRadius: 340),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomTrailing) { videoButton.padding(8) }
    }

    /// YouTube 只留一顆小按鈕：有精選影片就開那支，沒有就開搜尋（交給 YouTube App／瀏覽器）
    private var videoButton: some View {
        let v = DemoVideos.video(for: exercise)
        return Button {
            openURL(v.map(DemoVideos.watchURL) ?? DemoVideos.searchURL(for: exercise))
        } label: {
            Label(v != nil ? "YouTube 影片" : "搜尋影片", systemImage: "play.rectangle.fill")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(.black.opacity(0.55), in: Capsule())
                .foregroundStyle(Theme.fg)
        }
        .buttonStyle(.plain)
        .accessibilityHint(v != nil ? "在 YouTube 開啟示範影片" : "在 YouTube 搜尋這個動作的示範")
    }

    private var primary: [Muscle] { exercise.trainedMuscles.filter { $0.1 >= 1 }.map(\.0) }
    private var secondary: [Muscle] { exercise.trainedMuscles.filter { $0.1 < 1 }.map(\.0) }

    private func muscleFill(_ m: Muscle) -> Color {
        if primary.contains(m) { return Theme.hot }
        if secondary.contains(m) { return Theme.hot.opacity(0.42) }
        return MuscleMapView.idle
    }

    /// 肌群圖：正面＋背面，主要肌群深橘、次要淡橘
    private var muscleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("練到的肌群").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    MuscleMapView(side: .front, fill: muscleFill)
                    Text("正面").font(.caption2).foregroundStyle(Theme.muted)
                }
                VStack(spacing: 4) {
                    MuscleMapView(side: .back, fill: muscleFill)
                    Text("背面").font(.caption2).foregroundStyle(Theme.muted)
                }
            }
            .frame(height: 220)
            .accessibilityHidden(true)
            muscleLegend("主要", primary, Theme.hot)
            if !secondary.isEmpty { muscleLegend("次要", secondary, Theme.hot.opacity(0.42)) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func muscleLegend(_ title: String, _ list: [Muscle], _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(title).font(.caption.weight(.bold)).foregroundStyle(Theme.fg)
            Text(list.map(\.name).joined(separator: "、")).font(.subheadline).foregroundStyle(Theme.fg)
        }
        .accessibilityElement(children: .combine)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    demoStage
                    VStack(alignment: .leading, spacing: 4) {
                        Text("重點").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                        Text(exercise.tip).font(.subheadline).foregroundStyle(Theme.fg)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    muscleCard
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
