import XCTest
@testable import Workout

/// 3D 動作示範（0.56.0）：動作庫的每個動作都有對照、對照的動作檔和器材檔都在 App 裡、檔案內容彼此對得起來。
final class Hero3DMovesTests: XCTestCase {
    private let bundle = Bundle(for: Hero3DModel.self)

    /// 動作庫內建的每個動作都要有 3D 對照（沒有的話示範畫面只能用 2D）
    func testEveryBuiltInExerciseHasA3DMove() {
        let missing = ExerciseLibrary.builtIn.map(\.id).filter { Hero3DMoves.byExercise[$0] == nil }
        XCTAssertEqual(missing, [], "這些動作還沒對照 3D 動作：\(missing)")
    }

    /// 對照表沒有指到已經不存在的動作
    func testMappingHasNoUnknownExerciseIds() {
        let ids = Set(ExerciseLibrary.builtIn.map(\.id))
        let extra = Hero3DMoves.byExercise.keys.filter { !ids.contains($0) }
        XCTAssertEqual(extra.sorted(), [], "對照表多了動作庫沒有的 id")
    }

    /// 對照到的每個 3D 動作都有動作檔
    func testEveryMappedMoveHasAClipFile() {
        for (ex, move) in Hero3DMoves.byExercise.sorted(by: { $0.key < $1.key }) {
            XCTAssertNotNil(bundle.url(forResource: "hero3d_clip_\(move)", withExtension: "json"), "\(ex) → \(move) 沒有動作檔")
            XCTAssertNotNil(Hero3DMoves.move(for: ex), "\(ex) 應該有 3D 示範")
        }
    }

    /// 動作檔能讀、骨頭數和每格資料一致、有每個零件的接地資料
    func testClipFilesAreWellFormed() throws {
        for move in Set(Hero3DMoves.byExercise.values).sorted() {
            let url = try XCTUnwrap(bundle.url(forResource: "hero3d_clip_\(move)", withExtension: "json"), move)
            let clip = try JSONDecoder().decode(Hero3DClip.self, from: Data(contentsOf: url))
            XCTAssertEqual(clip.move, move)
            XCTAssertGreaterThan(clip.frames.count, 1, move)
            XCTAssertGreaterThan(clip.fps, 0, move)
            XCTAssertTrue(clip.frames.allSatisfy { $0.count == clip.joints.count && $0.allSatisfy { $0.count == 7 } }, "\(move) 每格每根骨頭要 7 個數")
            XCTAssertNotNil(clip.low["base"], "\(move) 沒有身體的接地資料")
            XCTAssertTrue(clip.low.values.allSatisfy { $0.count == clip.frames.count }, "\(move) 接地資料格數不對")
            XCTAssertNotNil(clip.bell, "\(move) 的動作檔是舊格式（沒有 bell 欄位），要用 build_moves.sh 重匯出")
        }
    }

    /// 器材檔：json 和 bin 成對、位置沒超出 bin、索引沒超出頂點、會動的零件格數等於動作格數、材質有定義
    func testPropFilesAreConsistent() throws {
        var withProps = 0
        for move in Set(Hero3DMoves.byExercise.values).sorted() {
            guard let ju = bundle.url(forResource: "hero3d_prop_\(move)", withExtension: "json") else {
                XCTAssertNil(bundle.url(forResource: "hero3d_prop_\(move)", withExtension: "bin"), "\(move) 有 bin 沒有 json")
                continue
            }
            withProps += 1
            let bu = try XCTUnwrap(bundle.url(forResource: "hero3d_prop_\(move)", withExtension: "bin"), "\(move) 有 json 沒有 bin")
            let bin = try Data(contentsOf: bu)
            let info = try JSONDecoder().decode(Hero3DPropInfo.self, from: Data(contentsOf: ju))
            let clipURL = try XCTUnwrap(bundle.url(forResource: "hero3d_clip_\(move)", withExtension: "json"))
            let clip = try JSONDecoder().decode(Hero3DClip.self, from: Data(contentsOf: clipURL))
            XCTAssertFalse(info.groups.isEmpty, move)
            for g in info.groups {
                XCTAssertLessThanOrEqual(g.pos + g.nv * 24 + g.ni * 4, bin.count, "\(move)/\(g.name) 超出 bin")
                XCTAssertEqual(g.ni % 3, 0, "\(move)/\(g.name) 索引不是三的倍數")
                XCTAssertNotNil(info.materials[g.mat], "\(move)/\(g.name) 沒有材質 \(g.mat)")
                if let a = g.anim {
                    XCTAssertEqual(a.count, clip.frames.count, "\(move)/\(g.name) 器材格數跟動作不同")
                    XCTAssertTrue(a.allSatisfy { $0.count == 10 }, "\(move)/\(g.name) 每格要 10 個數")
                }
                // 索引都指在頂點範圍內
                let o = g.pos + g.nv * 24
                let maxIdx = bin.withUnsafeBytes { raw in (0..<g.ni).map { i in raw.loadUnaligned(fromByteOffset: o + i * 4, as: UInt32.self) }.max() ?? 0 }
                XCTAssertLessThan(Int(maxIdx), g.nv, "\(move)/\(g.name) 索引超出頂點")
            }
        }
        XCTAssertGreaterThan(withProps, 20, "有器材的動作應該有 30 幾個")
    }

    /// 要靠器材才看得懂的動作，一定要有器材檔（臥推沒有椅子會變成躺在空中）
    func testPropMovesHavePropFiles() {
        for move in ["benchPress", "inclinePress", "pulldown", "pullup", "legPress", "machineChestPress", "benchDip", "kbSwing"] {
            XCTAssertNotNil(bundle.url(forResource: "hero3d_prop_\(move)", withExtension: "json"), "\(move) 缺器材檔")
        }
    }
}
