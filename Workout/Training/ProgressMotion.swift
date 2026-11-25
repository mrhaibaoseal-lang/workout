import SwiftUI
import Charts

// 進步頁、個人紀錄頁的進場動畫元件：
// 數字往上數（CountUpText）、折線圖由左往右畫出（chartDrawIn）、最新的點彈一下（ChartLastPointMarker）。
// 都只在第一次「看得到」的時候播；「減少動態效果」開啟時直接顯示最終結果。

// MARK: - 第一次看到

private struct FirstVisibleModifier: ViewModifier {
    let action: () -> Void
    @State private var fired = false

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                let f = geo.frame(in: .global)
                let visible = f.maxY > 0 && f.minY < UIScreen.main.bounds.height * 0.92
                Color.clear
                    .onChange(of: visible, initial: true) { _, v in
                        if v && !fired {
                            fired = true
                            action()
                        }
                    }
            }
        )
    }
}

extension View {
    /// 這個 view 第一次進到畫面裡時呼叫一次（之後捲動、重新整理都不會再呼叫）。
    func onFirstVisible(_ action: @escaping () -> Void) -> some View {
        modifier(FirstVisibleModifier(action: action))
    }
}

// MARK: - 數字往上數

private struct CountingLabel: View, Animatable {
    var value: Double
    let format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}

/// 第一次出現時從 0 數到目標值（約 0.8 秒、ease-out）。字型、顏色從外面接（用 `Theme.number` 就是等寬數字）。
/// 目標值之後改變（切換動作、練完新增一筆）時，從目前的數字平順數到新的值。
struct CountUpText: View {
    let target: Double
    let format: (Double) -> String
    var duration: Double = 0.8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0
    @State private var started = false

    init(_ value: Double, duration: Double = 0.8, format: @escaping (Double) -> String) {
        self.target = value
        self.duration = duration
        self.format = format
    }

    /// 整數（次數、週數）。
    init(_ value: Int, duration: Double = 0.8) {
        self.init(Double(value), duration: duration) { "\(Int($0.rounded()))" }
    }

    var body: some View {
        CountingLabel(value: reduceMotion ? target : shown, format: format)
            .onFirstVisible {
                started = true
                guard !reduceMotion else { shown = target; return }
                withAnimation(.easeOut(duration: duration)) { shown = target }
            }
            .onChange(of: target) { _, new in
                guard started else { return }
                if reduceMotion {
                    shown = new
                } else {
                    withAnimation(.easeOut(duration: 0.5)) { shown = new }
                }
            }
    }
}

// MARK: - 折線圖由左往右畫出

private struct ChartDrawInModifier: ViewModifier {
    var duration: Double = 0.9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        let p: CGFloat = reduceMotion ? 1 : progress
        return content
            .mask {
                // 左右多留一點，避免圖邊緣的點被切掉
                GeometryReader { g in
                    Rectangle()
                        .frame(width: (g.size.width + 24) * p, height: g.size.height + 40)
                        .offset(x: -12, y: -20)
                }
            }
            .onFirstVisible {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration)) { progress = 1 }
            }
    }
}

extension View {
    /// 折線圖第一次出現時，從左往右畫出來。切換資料不會重畫。
    func chartDrawIn() -> some View {
        modifier(ChartDrawInModifier())
    }
}

// MARK: - 最新的點

/// 疊在折線圖最後一個資料點上的小圓點；線畫完之後彈一下，再散出一圈光。
/// 用法：`.chartOverlay { proxy in ChartLastPointMarker(proxy: proxy, x: date, y: value, color: c) }`
struct ChartLastPointMarker: View {
    let proxy: ChartProxy
    let x: Date
    let y: Double
    let color: Color
    /// 要等折線畫完（和 `chartDrawIn` 的秒數一樣）才彈
    var delay: Double = 0.9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false
    @State private var ring = false

    var body: some View {
        GeometryReader { geo in
            if let frame = proxy.plotFrame,
               let px = proxy.position(forX: x),
               let py = proxy.position(forY: y) {
                let origin = geo[frame].origin
                ZStack {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 9, height: 9)
                        .scaleEffect(ring ? 3.4 : 1)
                        .opacity(ring ? 0 : (popped ? 0.85 : 0))
                    Circle()
                        .fill(color)
                        .frame(width: 9, height: 9)
                        .scaleEffect(reduceMotion || popped ? 1 : 0)
                }
                .position(x: origin.x + px, y: origin.y + py)
            }
        }
        .allowsHitTesting(false)
        .onFirstVisible {
            guard !reduceMotion else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.spring(response: 0.36, dampingFraction: 0.42)) { popped = true }
                withAnimation(.easeOut(duration: 0.7)) { ring = true }
            }
        }
    }
}
