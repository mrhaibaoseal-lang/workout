import SwiftUI
import UIKit

/// 等長動作（棒式）計時：倒數 3、2、1 → 往上數 → 到目標秒數震動，還撐得住就繼續 → 放下時填入秒數。
struct HoldTimerView: View {
    let name: String
    let target: Int
    let onDone: (Int) -> Void
    let onCancel: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var startAt = Date().addingTimeInterval(3)
    @State private var now = Date()
    @State private var lastCue = 99
    @State private var reached = false
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private static let alertId = "hold-target"

    private var countdown: Int? {
        let left = startAt.timeIntervalSince(now)
        return left > 0 ? Int(left.rounded(.up)) : nil
    }
    private var held: Double { max(0, now.timeIntervalSince(startAt)) }

    var body: some View {
        VStack(spacing: 20) {
            Text(name)
                .font(.title2.weight(.black))
                .foregroundStyle(Theme.fg)
            Text("目標 \(target) 秒")
                .font(.headline)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            ZStack {
                Ring(progress: countdown == nil ? held / Double(max(target, 1)) : 0,
                     color: reached ? Theme.green : Theme.hot, lineWidth: 16)
                if let c = countdown {
                    VStack(spacing: 4) {
                        Text("準備").font(.title3.weight(.bold)).foregroundStyle(Theme.gold)
                        Text("\(c)")
                            .font(Theme.number(120))
                            .foregroundStyle(Theme.gold)
                            .contentTransition(.numericText())
                    }
                } else {
                    VStack(spacing: 4) {
                        Text(reached ? "到目標了！還撐得住就繼續" : "撐住")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(reached ? Theme.green : Theme.hotText)
                        Text("\(Int(held))")
                            .font(Theme.number(110))
                            .foregroundStyle(Theme.fg)
                            .contentTransition(.numericText())
                        Text("秒").font(.headline).foregroundStyle(Theme.muted)
                    }
                }
            }
            .frame(width: 290, height: 290)
            Spacer(minLength: 0)
            Button {
                finish()
            } label: {
                Text(countdown == nil ? "放下（記錄 \(Int(held)) 秒）" : "取消")
            }
            .buttonStyle(HotButtonStyle(height: 64))
            if countdown == nil {
                Button("取消，不記錄") { stop(); onCancel() }
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(24)
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            Cue.play(.count)
            lastCue = 3
            ToolAlerts.schedule(id: Self.alertId, at: startAt.addingTimeInterval(Double(target)),
                                title: "\(name) 到 \(target) 秒了！", body: "還撐得住就繼續，放下時回到練壯記錄。")
        }
        .onDisappear { stop() }
        .onReceive(timer) { _ in tick() }
        .onChange(of: scenePhase) { _, p in
            // 從背景回來：不補播錯過的聲音
            if p == .active { now = Date(); reached = held >= Double(target); lastCue = cueMark }
        }
    }

    /// 倒數時是 3、2、1；開始後是秒數（每 10 秒一聲小提醒、目標前 3 秒倒數）
    private var cueMark: Int { countdown ?? -Int(held) }

    private func tick() {
        now = Date()
        if let c = countdown {
            if c != lastCue { lastCue = c; Cue.play(.count) }
            return
        }
        let s = Int(held)
        let mark = -s
        guard mark != lastCue else { return }
        lastCue = mark
        if s == 0 {
            Cue.play(.go)
        } else if !reached && s >= target {
            reached = true
            Cue.play(.done)
        } else if !reached && target - s <= 3 {
            Cue.play(.count)
        } else if s % 10 == 0 {
            Cue.play(.tick)
        }
    }

    private func finish() {
        if countdown != nil {
            stop()
            onCancel()
        } else {
            let s = Int(held)
            stop()
            onDone(s)
        }
    }

    private func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        ToolAlerts.cancel(prefix: Self.alertId)
    }
}
