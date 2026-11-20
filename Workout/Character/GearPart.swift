import SwiftUI

/// 裝備造型的一塊：掛在身體某個部位的局部座標上（見 scripts/art/gear.js 開頭的說明）。
struct GearPart {
    enum Anchor { case torso, nape, thigh, shin, foot, upper, fore, fist, grip }
    /// back：身體外框之前；limb：畫完該肢段後；over：全部肢段後、頭之前；grip：頭之後（啞鈴）
    enum Z { case back, limb, over, grip }

    let anchor: Anchor
    let z: Z
    /// 遠側肢段也畫一份（較暗）
    let far: Bool
    let layers: [ArtLayer]
}
