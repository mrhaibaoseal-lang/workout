import Foundation
import SwiftUI
import UIKit

/// 匯出 CSV：每組紀錄、身體數據（有間歇紀錄就多一個檔）。
/// UTF-8 加 BOM、CRLF 換行，Excel 直接打開中文不會亂碼。重量一律 kg。
enum CSVExport {
    static func files(sessions: [WorkoutSession], bodies: [BodyLog], intervals: [IntervalLog]) throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("export", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = dayFmt.string(from: .now)
        var urls: [URL] = []

        var sets: [[String]] = [["日期", "時間", "課表", "長度", "動作", "動作代號", "類型", "第幾組", "重量 (kg)", "次數或秒數", "單位", "還能再做幾下", "單手：另一手次數", "單手：另一手還能再做幾下"]]
        for s in sessions.sorted(by: { $0.date < $1.date }) {
            let entries = s.entries.sorted { ($0.date, $0.setIndex) < ($1.date, $1.setIndex) }
            for e in entries {
                let ex = ExerciseLibrary.byId(e.exerciseId)
                sets.append([
                    dayFmt.string(from: s.date), timeFmt.string(from: e.date), s.dayName, s.length.rawValue,
                    ex?.name ?? e.exerciseId, e.exerciseId, SetKind(rawValue: e.kind)?.title ?? e.kind,
                    "\(e.setIndex + 1)", ex?.loaded == false && e.weight == 0 ? "" : num(e.weight), "\(e.reps)",
                    ex?.unit.label ?? "下", e.rir >= 0 ? "\(e.rir)" : "",
                    e.otherReps >= 0 ? "\(e.otherReps)" : "", e.otherRir >= 0 ? "\(e.otherRir)" : "",
                ])
            }
        }
        urls.append(try write(sets, name: "練壯_每組紀錄_\(stamp).csv", in: dir))

        var body: [[String]] = [["日期", "體重 (kg)", "體脂 (%)", "肩 (cm)", "胸 (cm)", "手臂 (cm)", "腰 (cm)", "臀 (cm)", "大腿 (cm)", "小腿 (cm)"]]
        for b in bodies.sorted(by: { $0.date < $1.date }) {
            body.append([dayFmt.string(from: b.date)] +
                        [b.weight, b.bodyFat, b.shoulders, b.chest, b.arm, b.waist, b.hips, b.thigh, b.calf]
                            .map { $0 > 0 ? num($0) : "" })
        }
        urls.append(try write(body, name: "練壯_身體數據_\(stamp).csv", in: dir))

        if !intervals.isEmpty {
            var rows: [[String]] = [["日期", "時間", "類型", "設定", "實際秒數", "回合或輪數", "提早結束"]]
            for l in intervals.sorted(by: { $0.date < $1.date }) {
                rows.append([dayFmt.string(from: l.date), timeFmt.string(from: l.date), l.title, l.detail,
                             "\(l.durationSeconds)", "\(l.rounds)", l.stoppedEarly ? "是" : ""])
            }
            urls.append(try write(rows, name: "練壯_間歇計時_\(stamp).csv", in: dir))
        }
        return urls
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func write(_ rows: [[String]], name: String, in dir: URL) throws -> URL {
        let text = "\u{FEFF}" + rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        let url = dir.appendingPathComponent(name)
        try Data(text.utf8).write(to: url, options: .atomic)
        return url
    }

    private static func num(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()
}

/// 系統分享選單（存到「檔案」、AirDrop、傳給別人）
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
