import Foundation
import UIKit
import Vision

/// Reads a weekly timetable screenshot (columns = 週一…, rows = periods with
/// start times like 08:10) and turns each course box into a ClassBlock.
enum TimetableOCR {
    struct Line {
        let text: String
        /// Vision's normalized box: origin bottom-left, y grows upward.
        let box: CGRect
    }

    static func recognize(_ image: UIImage) async throws -> [Line] {
        guard let cg = image.cgImage else { return [] }
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["zh-Hant", "en-US"]
                request.usesLanguageCorrection = false
                do {
                    try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
                    let lines = (request.results ?? []).compactMap { obs -> Line? in
                        guard let top = obs.topCandidates(1).first else { return nil }
                        return Line(text: top.string.trimmingCharacters(in: .whitespaces), box: obs.boundingBox)
                    }
                    cont.resume(returning: lines)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    static func parse(_ lines: [Line], periodMinutes: Int = 50) -> [ClassBlock] {
        var headers: [(x: CGFloat, y: CGFloat, weekday: Int)] = []
        var times: [(y: CGFloat, minutes: Int)] = []
        var rest: [Line] = []

        for l in lines {
            if let wd = weekday(in: l.text) {
                headers.append((l.box.midX, l.box.midY, wd))
            } else if let m = startMinutes(in: l.text) {
                times.append((l.box.midY, m))
            } else {
                rest.append(l)
            }
        }
        guard !headers.isEmpty, times.count >= 2 else { return [] }

        headers.sort { $0.x < $1.x }
        times.sort { $0.y > $1.y }   // top row first

        let colWidth: CGFloat = headers.count > 1
            ? median(zip(headers.dropFirst(), headers).map { $0.x - $1.x })
            : 0.15
        let rowSpacing = median(zip(times, times.dropFirst()).map { $0.y - $1.y })
        let headerBottom = headers.map(\.y).min()!

        // Course text sits below the header row, inside a day column.
        var columns: [Int: [Line]] = [:]
        for l in rest {
            guard l.box.midY < headerBottom - 0.005,
                  !isPeriodNumber(l.text), !l.text.isEmpty else { continue }
            guard let col = headers.min(by: { abs($0.x - l.box.midX) < abs($1.x - l.box.midX) }),
                  abs(col.x - l.box.midX) < colWidth * 0.6 else { continue }
            columns[col.weekday, default: []].append(l)
        }

        var result: [ClassBlock] = []
        for (weekday, colLines) in columns {
            let sorted = colLines.sorted { $0.box.midY > $1.box.midY }
            var groups: [[Line]] = []
            for l in sorted {
                if let prev = groups.last?.last,
                   !isRoom(prev.text),
                   prev.box.minY - l.box.maxY < max(l.box.height, prev.box.height) * 1.3 {
                    groups[groups.count - 1].append(l)
                } else {
                    groups.append([l])
                }
            }

            for g in groups {
                let names = g.filter { !isRoom($0.text) }.map(\.text)
                guard !names.isEmpty else { continue }
                let rooms = g.filter { isRoom($0.text) }.map(\.text)
                let top = g.map(\.box.maxY).max()!
                let bottom = g.map(\.box.minY).min()!
                let center = (top + bottom) / 2

                // Fractional row index of the text centre (0 = first period's label).
                let f = (times[0].y - center) / rowSpacing
                let first: Int, last: Int
                let frac = f - f.rounded(.down)
                if abs(frac - 0.5) < 0.25 {
                    first = Int(f.rounded(.down)); last = first + 1     // centred on a boundary: 2 periods
                } else {
                    let mid = Int(f.rounded()); first = mid - 1; last = mid + 1   // centred on a row: 3 periods
                }
                let a = min(max(first, 0), times.count - 1)
                let b = min(max(last, a), times.count - 1)

                result.append(ClassBlock(weekday: weekday,
                                         startMin: times[a].minutes,
                                         endMin: times[b].minutes + periodMinutes,
                                         name: names.joined(),
                                         room: rooms.joined(separator: ", ")))
            }
        }
        return result.sorted { ($0.weekday + 5) % 7 != ($1.weekday + 5) % 7
            ? ($0.weekday + 5) % 7 < ($1.weekday + 5) % 7
            : $0.startMin < $1.startMin }
    }

    // MARK: - helpers

    private static let dayChars: [Character: Int] = ["一": 2, "二": 3, "三": 4, "四": 5, "五": 6, "六": 7, "日": 1, "天": 1]

    private static func weekday(in text: String) -> Int? {
        let t = text.replacingOccurrences(of: " ", with: "")
        for prefix in ["週", "周", "星期", "禮拜"] where t.hasPrefix(prefix) {
            let restText = t.dropFirst(prefix.count)
            if restText.count == 1, let c = restText.first, let wd = dayChars[c] { return wd }
        }
        return nil
    }

    private static func startMinutes(in text: String) -> Int? {
        let t = text.replacingOccurrences(of: "：", with: ":").replacingOccurrences(of: " ", with: "")
        guard t.count <= 11, let r = t.range(of: #"^\d{1,2}:\d{2}"#, options: .regularExpression) else { return nil }
        return TimeFmt.parse(String(t[r]))
    }

    private static func isPeriodNumber(_ text: String) -> Bool {
        text.range(of: #"^\d{1,2}$"#, options: .regularExpression) != nil
    }

    private static func isRoom(_ text: String) -> Bool {
        text.replacingOccurrences(of: " ", with: "")
            .range(of: #"^[A-Z]{1,3}\d{2,4}([,，、][A-Z]{1,3}\d{2,4})*$"#, options: .regularExpression) != nil
    }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        let s = values.sorted()
        return s.isEmpty ? 0.1 : s[s.count / 2]
    }
}
