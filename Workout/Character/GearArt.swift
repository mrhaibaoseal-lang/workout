// 自動產生，請勿手改：node scripts/art/gear.js
// 每件裝備的造型圖層（局部座標說明見 scripts/art/gear.js 開頭）。

enum GearArt {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parts(_ id: String) -> [GearPart] {
        switch id {
        case "basic.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#9AA4AF", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-8 -5 L-9.5 -7.5 L-14.5 -7.5 L-16 -5 L-16 5 L-14.5 7.5 L-9.5 7.5 L-8 5 Z", .linear(["#4A525E", "#1B2027"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-12 -7 L-12 7", .solid("#000000", 0), stroke: "#6B7480", width: 1),
                    ArtLayer("M8 -5 L9.5 -7.5 L14.5 -7.5 L16 -5 L16 5 L14.5 7.5 L9.5 7.5 L8 5 Z", .linear(["#4A525E", "#1B2027"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M12 -7 L12 7", .solid("#000000", 0), stroke: "#6B7480", width: 1)
                ])
            ]
        case "basic.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-6 -3 Q-8 6 -2 9 L5 9 Q9 5 14 4 Q21 2 21 -1 L21 -3 Z", .solid("#F4F5F7", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-7 -3 L22 -3 Q24.5 -4.5 22 -5.5 L-6 -5.5 Q-8.5 -5.333333333333333 -7 -3 Z", .solid("#C9D1DA", 1), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M3 7 L6 3.5", .solid("#000000", 0), stroke: "#9AA4AF", width: 1.2),
                    ArtLayer("M6 7.5 L9 4.5", .solid("#000000", 0), stroke: "#9AA4AF", width: 1.2)
                ])
            ]
        case "basic.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-9.5 -7 L-5.5 -7 Q-4 -7 -4 -5.5 L-4 5.5 Q-4 7 -5.5 7 L-9.5 7 Q-11 7 -11 5.5 L-11 -5.5 Q-11 -7 -9.5 -7 Z", .solid("#FFFFFF", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-9.5 -6 L-9.5 6", .solid("#000000", 0), stroke: "#C9D1DA", width: 1)
                ])
            ]
        case "basic.top":
            return [
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M42 15 Q36 6 44 0", .solid("#000000", 0), stroke: "#2A303A", width: 2),
                    ArtLayer("M30 -13.6 Q40 -8 46 -4", .solid("#000000", 0), stroke: "#2A303A", width: 1.6)
                ])
            ]
        case "basic.bottom":
            return [
                GearPart(anchor: .thigh, z: .limb, far: true, layers: [
                    ArtLayer("M20 -9 L20 9", .solid("#000000", 0), stroke: "#14181E", width: 2)
                ])
            ]
        case "street.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#E6EBF0", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-9.3 -8 L-8.7 -8 Q-7.5 -8 -7.5 -6.8 L-7.5 6.8 Q-7.5 8 -8.7 8 L-9.3 8 Q-10.5 8 -10.5 6.8 L-10.5 -6.8 Q-10.5 -8 -9.3 -8 Z", .linear(["#FFFFFF", "#9AA4AF"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-12.8 -6.5 L-11.7 -6.5 Q-10.5 -6.5 -10.5 -5.3 L-10.5 5.3 Q-10.5 6.5 -11.7 6.5 L-12.8 6.5 Q-14 6.5 -14 5.3 L-14 -5.3 Q-14 -6.5 -12.8 -6.5 Z", .linear(["#FFFFFF", "#B9C2CC"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-15.5 -4.5 L-15 -4.5 Q-14 -4.5 -14 -3.5 L-14 3.5 Q-14 4.5 -15 4.5 L-15.5 4.5 Q-16.5 4.5 -16.5 3.5 L-16.5 -3.5 Q-16.5 -4.5 -15.5 -4.5 Z", .linear(["#FFFFFF", "#C9D1DA"]), stroke: "#0A0D12", width: 1.4),
                    ArtLayer("M8.7 -8 L9.3 -8 Q10.5 -8 10.5 -6.8 L10.5 6.8 Q10.5 8 9.3 8 L8.7 8 Q7.5 8 7.5 6.8 L7.5 -6.8 Q7.5 -8 8.7 -8 Z", .linear(["#FFFFFF", "#9AA4AF"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M11.7 -6.5 L12.8 -6.5 Q14 -6.5 14 -5.3 L14 5.3 Q14 6.5 12.8 6.5 L11.7 6.5 Q10.5 6.5 10.5 5.3 L10.5 -5.3 Q10.5 -6.5 11.7 -6.5 Z", .linear(["#FFFFFF", "#B9C2CC"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M15 -4.5 L15.5 -4.5 Q16.5 -4.5 16.5 -3.5 L16.5 3.5 Q16.5 4.5 15.5 4.5 L15 4.5 Q14 4.5 14 3.5 L14 -3.5 Q14 -4.5 15 -4.5 Z", .linear(["#FFFFFF", "#C9D1DA"]), stroke: "#0A0D12", width: 1.4)
                ])
            ]
        case "street.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-7 -3 Q-8 14 -5 16 L6 16 Q7 8 10 5 Q20 3 21 0 L21 -3 Z", .solid("#2F6FE0", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-7 -3 L22 -3 Q24.5 -4.5 22 -7 L-6 -7 Q-8.5 -5.833333333333333 -7 -3 Z", .solid("#FFFFFF", 1), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M-3 3 Q6 5 14 1", .solid("#000000", 0), stroke: "#FFFFFF", width: 2.2),
                    ArtLayer("M1 14 L0.2 12.1 L-1.9 11.9 L-0.2 10.6 L-0.8 8.6 L1 9.7 L2.8 8.6 L2.2 10.6 L3.9 11.9 L1.8 12.1 Z", .solid("#FFCC33", 1), stroke: "#0A0D12", width: 1),
                    ArtLayer("M-5.5 13 L4.5 13 Q6 13 6 14.5 L6 15 Q6 16.5 4.5 16.5 L-5.5 16.5 Q-7 16.5 -7 15 L-7 14.5 Q-7 13 -5.5 13 Z", .solid("#FFFFFF", 1), stroke: "#0A0D12", width: 1.4)
                ])
            ]
        case "street.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-7 -7 L-3 -7 Q-1 -7 -1 -5 L-1 5 Q-1 7 -3 7 L-7 7 Q-9 7 -9 5 L-9 -5 Q-9 -7 -7 -7 Z", .solid("#E6EBF0", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M1.5 -5.5 C4.8 -5.5 7.5 -3 7.5 0 C7.5 3 4.8 5.5 1.5 5.5 C-1.8 5.5 -4.5 3 -4.5 0 C-4.5 -3 -1.8 -5.5 1.5 -5.5 Z", .solid("#F4F5F7", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M4 3 L6.5 1", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4 -1.5 L6.5 -3", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M-6 -7.5 L-4 -7.5 Q-3 -7.5 -3 -6.5 L-3 6.5 Q-3 7.5 -4 7.5 L-6 7.5 Q-7 7.5 -7 6.5 L-7 -6.5 Q-7 -7.5 -6 -7.5 Z", .solid("#2F6FE0", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M5 -4.5 C6.4 -4.5 7.6 -2.5 7.6 0 C7.6 2.5 6.4 4.5 5 4.5 C3.6 4.5 2.4 2.5 2.4 0 C2.4 -2.5 3.6 -4.5 5 -4.5 Z", .solid("#E9BE9C", 1), stroke: "#0A0D12", width: 1.2)
                ])
            ]
        case "street.top":
            return [
                GearPart(anchor: .nape, z: .over, far: false, layers: [
                    ArtLayer("M4 -6 Q16 -10 12 -22 Q4 -28 -6 -20 Q-10 -12 -4 -8 Z", .solid("#2F6FE0", 1), stroke: "#0A0D12", width: 2.6),
                    ArtLayer("M2 -10 Q9 -13 7 -19", .solid("#000000", 0), stroke: "#1D4FA8", width: 2)
                ]),
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M10 2 L18 2 Q22 2 22 6 L22 9 Q22 13 18 13 L10 13 Q6 13 6 9 L6 6 Q6 2 10 2 Z", .solid("#2558B8", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M44 8 L34 9", .solid("#000000", 0), stroke: "#FFFFFF", width: 1.6),
                    ArtLayer("M44 4 L32 5", .solid("#000000", 0), stroke: "#FFFFFF", width: 1.6),
                    ArtLayer("M33.5 7.6 C34.3 7.6 34.9 8.2 34.9 9 C34.9 9.8 34.3 10.4 33.5 10.4 C32.7 10.4 32.1 9.8 32.1 9 C32.1 8.2 32.7 7.6 33.5 7.6 Z", .solid("#FFFFFF", 1)),
                    ArtLayer("M31.5 3.6 C32.3 3.6 32.9 4.2 32.9 5 C32.9 5.8 32.3 6.4 31.5 6.4 C30.7 6.4 30.1 5.8 30.1 5 C30.1 4.2 30.7 3.6 31.5 3.6 Z", .solid("#FFFFFF", 1)),
                    ArtLayer("M1 -11 L3 -11 Q4 -11 4 -10 L4 10 Q4 11 3 11 L1 11 Q0 11 0 10 L0 -10 Q0 -11 1 -11 Z", .solid("#2558B8", 1))
                ])
            ]
        case "street.bottom":
            return [
                GearPart(anchor: .thigh, z: .limb, far: true, layers: [
                    ArtLayer("M-4 -11 Q12 -13 25 -13.5 Q27.5 0 26 12.5 Q12 12 -4 11 Z", .solid("#FFFFFF", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M0 -11 L24 -12.5", .solid("#000000", 0), stroke: "#2F6FE0", width: 3),
                    ArtLayer("M23 -12 L24 11", .solid("#000000", 0), stroke: "#2F6FE0", width: 2)
                ])
            ]
        case "neon.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#2A3340", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-13 -7 L-11 -7 Q-8 -7 -8 -4 L-8 4 Q-8 7 -11 7 L-13 7 Q-16 7 -16 4 L-16 -4 Q-16 -7 -13 -7 Z", .solid("#141A24", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-12 -6 L-12 6", .solid("#000000", 0), stroke: "#19E3FF", width: 4.1, blur: 2.5),
                    ArtLayer("M-12 -6 L-12 6", .solid("#000000", 0), stroke: "#19E3FF", width: 1.6),
                    ArtLayer("M-12 -6 L-12 6", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M11 -7 L13 -7 Q16 -7 16 -4 L16 4 Q16 7 13 7 L11 7 Q8 7 8 4 L8 -4 Q8 -7 11 -7 Z", .solid("#141A24", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M12 -6 L12 6", .solid("#000000", 0), stroke: "#19E3FF", width: 4.1, blur: 2.5),
                    ArtLayer("M12 -6 L12 6", .solid("#000000", 0), stroke: "#19E3FF", width: 1.6),
                    ArtLayer("M12 -6 L12 6", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "neon.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-6 -3 Q-8 6 -2 9 L5 9 Q9 5 14 4 Q21 2 21 -1 L21 -3 Z", .solid("#1B2230", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-6 -4.5 L22 -4.5", .solid("#000000", 0), stroke: "#FF3DCB", width: 4.5, blur: 2.5),
                    ArtLayer("M-6 -4.5 L22 -4.5", .solid("#000000", 0), stroke: "#FF3DCB", width: 2),
                    ArtLayer("M-6 -4.5 L22 -4.5", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M-3 4 L8 7", .solid("#000000", 0), stroke: "#19E3FF", width: 3.6, blur: 2.5),
                    ArtLayer("M-3 4 L8 7", .solid("#000000", 0), stroke: "#19E3FF", width: 1.1),
                    ArtLayer("M-3 4 L8 7", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "neon.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-8 -7 L-2 -7 Q0 -7 0 -5 L0 5 Q0 7 -2 7 L-8 7 Q-10 7 -10 5 L-10 -5 Q-10 -7 -8 -7 Z", .solid("#141A24", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M1.5 -6 C5.1 -6 8 -3.3 8 0 C8 3.3 5.1 6 1.5 6 C-2.1 6 -5 3.3 -5 0 C-5 -3.3 -2.1 -6 1.5 -6 Z", .solid("#141A24", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M4 3 L6.5 1", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4 -1.5 L6.5 -3", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M5 -4 L5 4", .solid("#000000", 0), stroke: "#19E3FF", width: 3.9, blur: 2.5),
                    ArtLayer("M5 -4 L5 4", .solid("#000000", 0), stroke: "#19E3FF", width: 1.4),
                    ArtLayer("M5 -4 L5 4", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M-8 -5.5 L-8 5.5", .solid("#000000", 0), stroke: "#FF3DCB", width: 3.5, blur: 2.5),
                    ArtLayer("M-8 -5.5 L-8 5.5", .solid("#000000", 0), stroke: "#FF3DCB", width: 1),
                    ArtLayer("M-8 -5.5 L-8 5.5", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "neon.top":
            return [
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M6 4 L18 4 L24 9 L40 9", .solid("#000000", 0), stroke: "#19E3FF", width: 3.7, blur: 2.5),
                    ArtLayer("M6 4 L18 4 L24 9 L40 9", .solid("#000000", 0), stroke: "#19E3FF", width: 1.2),
                    ArtLayer("M6 4 L18 4 L24 9 L40 9", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M12 -4 L28 -4 L34 2 L44 2", .solid("#000000", 0), stroke: "#FF3DCB", width: 3.6, blur: 2.5),
                    ArtLayer("M12 -4 L28 -4 L34 2 L44 2", .solid("#000000", 0), stroke: "#FF3DCB", width: 1.1),
                    ArtLayer("M12 -4 L28 -4 L34 2 L44 2", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M40 6.8 C41.2 6.8 42.2 7.8 42.2 9 C42.2 10.2 41.2 11.2 40 11.2 C38.8 11.2 37.8 10.2 37.8 9 C37.8 7.8 38.8 6.8 40 6.8 Z", .solid("#19E3FF", 1), stroke: "#0A0D12", width: 1),
                    ArtLayer("M44 -0.2 C45.2 -0.2 46.2 0.8 46.2 2 C46.2 3.2 45.2 4.2 44 4.2 C42.8 4.2 41.8 3.2 41.8 2 C41.8 0.8 42.8 -0.2 44 -0.2 Z", .solid("#FF3DCB", 1), stroke: "#0A0D12", width: 1)
                ])
            ]
        case "neon.bottom":
            return [
                GearPart(anchor: .shin, z: .limb, far: true, layers: [
                    ArtLayer("M1 3.4 C3 3.4 4.6 5 4.6 7 C4.6 9 3 10.6 1 10.6 C-1 10.6 -2.6 9 -2.6 7 C-2.6 5 -1 3.4 1 3.4 Z", .solid("#FF3DCB", 1), blur: 2.5),
                    ArtLayer("M1 4 C2.7 4 4 5.3 4 7 C4 8.7 2.7 10 1 10 C-0.7 10 -2 8.7 -2 7 C-2 5.3 -0.7 4 1 4 Z", .solid("#FF3DCB", 1), stroke: "#0A0D12", width: 1.2),
                    ArtLayer("M1 5.8 C1.7 5.8 2.2 6.3 2.2 7 C2.2 7.7 1.7 8.2 1 8.2 C0.3 8.2 -0.2 7.7 -0.2 7 C-0.2 6.3 0.3 5.8 1 5.8 Z", .solid("#FFFFFF", 1)),
                    ArtLayer("M33 -7 L33 7", .solid("#000000", 0), stroke: "#19E3FF", width: 3.7, blur: 2.5),
                    ArtLayer("M33 -7 L33 7", .solid("#000000", 0), stroke: "#19E3FF", width: 1.2),
                    ArtLayer("M33 -7 L33 7", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "neon.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M17.8 -8.9 Q16.9 -1.7 12.5 4.1", .solid("#000000", 0), stroke: "#19E3FF", width: 4.5, blur: 2.5),
                    ArtLayer("M17.8 -8.9 Q16.9 -1.7 12.5 4.1", .solid("#000000", 0), stroke: "#19E3FF", width: 2),
                    ArtLayer("M17.8 -8.9 Q16.9 -1.7 12.5 4.1", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M8.1 8.5 Q2.3 12.9 -4.9 13.8", .solid("#000000", 0), stroke: "#FF3DCB", width: 4.5, blur: 2.5),
                    ArtLayer("M8.1 8.5 Q2.3 12.9 -4.9 13.8", .solid("#000000", 0), stroke: "#FF3DCB", width: 2),
                    ArtLayer("M8.1 8.5 Q2.3 12.9 -4.9 13.8", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M-11.1 13.8 Q-18.3 12.9 -24.1 8.5", .solid("#000000", 0), stroke: "#19E3FF", width: 4.5, blur: 2.5),
                    ArtLayer("M-11.1 13.8 Q-18.3 12.9 -24.1 8.5", .solid("#000000", 0), stroke: "#19E3FF", width: 2),
                    ArtLayer("M-11.1 13.8 Q-18.3 12.9 -24.1 8.5", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M-28.5 4.1 Q-32.9 -1.7 -33.8 -8.9", .solid("#000000", 0), stroke: "#FF3DCB", width: 4.5, blur: 2.5),
                    ArtLayer("M-28.5 4.1 Q-32.9 -1.7 -33.8 -8.9", .solid("#000000", 0), stroke: "#FF3DCB", width: 2),
                    ArtLayer("M-28.5 4.1 Q-32.9 -1.7 -33.8 -8.9", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M-33.8 -15.1 Q-32.9 -22.3 -28.5 -28.1", .solid("#000000", 0), stroke: "#19E3FF", width: 4.5, blur: 2.5),
                    ArtLayer("M-33.8 -15.1 Q-32.9 -22.3 -28.5 -28.1", .solid("#000000", 0), stroke: "#19E3FF", width: 2),
                    ArtLayer("M-33.8 -15.1 Q-32.9 -22.3 -28.5 -28.1", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M-24.1 -32.5 Q-18.3 -36.9 -11.1 -37.8", .solid("#000000", 0), stroke: "#FF3DCB", width: 4.5, blur: 2.5),
                    ArtLayer("M-24.1 -32.5 Q-18.3 -36.9 -11.1 -37.8", .solid("#000000", 0), stroke: "#FF3DCB", width: 2),
                    ArtLayer("M-24.1 -32.5 Q-18.3 -36.9 -11.1 -37.8", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M-4.9 -37.8 Q2.3 -36.9 8.1 -32.5", .solid("#000000", 0), stroke: "#19E3FF", width: 4.5, blur: 2.5),
                    ArtLayer("M-4.9 -37.8 Q2.3 -36.9 8.1 -32.5", .solid("#000000", 0), stroke: "#19E3FF", width: 2),
                    ArtLayer("M-4.9 -37.8 Q2.3 -36.9 8.1 -32.5", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M12.5 -28.1 Q16.9 -22.3 17.8 -15.1", .solid("#000000", 0), stroke: "#FF3DCB", width: 4.5, blur: 2.5),
                    ArtLayer("M12.5 -28.1 Q16.9 -22.3 17.8 -15.1", .solid("#000000", 0), stroke: "#FF3DCB", width: 2),
                    ArtLayer("M12.5 -28.1 Q16.9 -22.3 17.8 -15.1", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M-8 -16 C-5.8 -16 -4 -14.2 -4 -12 C-4 -9.8 -5.8 -8 -8 -8 C-10.2 -8 -12 -9.8 -12 -12 C-12 -14.2 -10.2 -16 -8 -16 Z", .solid("#19E3FF", 1), stroke: "#0A0D12", width: 1.4)
                ])
            ]
        case "lava.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#3A2A26", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-8 -4 L-10 -8 L-15 -7 L-17 -2 L-16 5 L-12 8 L-8 5 Z", .linear(["#4A332C", "#1E1210"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-10 -5 L-13 -1 L-11 2 L-14 6", .solid("#000000", 0), stroke: "#FF5A1F", width: 3.7, blur: 2.5),
                    ArtLayer("M-10 -5 L-13 -1 L-11 2 L-14 6", .solid("#000000", 0), stroke: "#FF5A1F", width: 1.2),
                    ArtLayer("M-10 -5 L-13 -1 L-11 2 L-14 6", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M8 -4 L10 -8 L15 -7 L17 -2 L16 5 L12 8 L8 5 Z", .linear(["#4A332C", "#1E1210"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M10 -5 L13 -1 L11 2 L14 6", .solid("#000000", 0), stroke: "#FF5A1F", width: 3.7, blur: 2.5),
                    ArtLayer("M10 -5 L13 -1 L11 2 L14 6", .solid("#000000", 0), stroke: "#FF5A1F", width: 1.2),
                    ArtLayer("M10 -5 L13 -1 L11 2 L14 6", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "lava.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-11 -2 Q-18 3 -14 8 Q-13 3 -8 3 Z M-10 -5 Q-20 -6 -17 0 Q-14 -3 -7 -1 Z", .linear(["#FFC23D", "#FF5A1F"])),
                    ArtLayer("M-11 -2 Q-18 3 -14 8 Q-13 3 -8 3 Z M-10 -5 Q-20 -6 -17 0 Q-14 -3 -7 -1 Z", .solid("#FF5A1F", 0.8), blur: 2.5),
                    ArtLayer("M-7 -3 Q-8 14 -6 17 L6 17 Q6 8 10 6 Q21 4 22 -1 L22 -3 Z", .linear(["#4A332C", "#1E1210"]), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-7 -3 L22 -3 Q24.5 -4.5 22 -7 L-6 -7 Q-8.5 -5.833333333333333 -7 -3 Z", .solid("#140A08", 1), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M-3 14 L0 9 L-2 6 L3 2", .solid("#000000", 0), stroke: "#FF5A1F", width: 3.6, blur: 2.5),
                    ArtLayer("M-3 14 L0 9 L-2 6 L3 2", .solid("#000000", 0), stroke: "#FF5A1F", width: 1.1),
                    ArtLayer("M-3 14 L0 9 L-2 6 L3 2", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M10 4 L14 1.5", .solid("#000000", 0), stroke: "#FFC23D", width: 3.5, blur: 2.5),
                    ArtLayer("M10 4 L14 1.5", .solid("#000000", 0), stroke: "#FFC23D", width: 1),
                    ArtLayer("M10 4 L14 1.5", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "lava.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-2 -7 Q2 -16 8 -12 Q6 -9 10 -8 Q12 -13 15 -6 Q17 -2 14 2 Q20 0 16 8 Q12 10 8 8 Z", .linear(["#FFC23D", "#FF5A1F"])),
                    ArtLayer("M-2 -7 Q2 -16 8 -12 Q6 -9 10 -8 Q12 -13 15 -6 Q17 -2 14 2 Q20 0 16 8 Q12 10 8 8 Z", .solid("#FF5A1F", 0.8), blur: 3),
                    ArtLayer("M-8 -7.5 L-2 -7.5 Q0 -7.5 0 -5.5 L0 5.5 Q0 7.5 -2 7.5 L-8 7.5 Q-10 7.5 -10 5.5 L-10 -5.5 Q-10 -7.5 -8 -7.5 Z", .solid("#2A1A16", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M1.5 -7 C5.6 -7 9 -3.9 9 0 C9 3.9 5.6 7 1.5 7 C-2.6 7 -6 3.9 -6 0 C-6 -3.9 -2.6 -7 1.5 -7 Z", .solid("#3A2420", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M4 3 L6.5 1", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4 -1.5 L6.5 -3", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M1 -5 L4 -1 L2 3", .solid("#000000", 0), stroke: "#FF5A1F", width: 3.5, blur: 2.5),
                    ArtLayer("M1 -5 L4 -1 L2 3", .solid("#000000", 0), stroke: "#FF5A1F", width: 1),
                    ArtLayer("M1 -5 L4 -1 L2 3", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "lava.top":
            return [
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M4 6 L12 2 L10 -4 L18 -8", .solid("#000000", 0), stroke: "#FF5A1F", width: 3.9, blur: 2.5),
                    ArtLayer("M4 6 L12 2 L10 -4 L18 -8", .solid("#000000", 0), stroke: "#FF5A1F", width: 1.4),
                    ArtLayer("M4 6 L12 2 L10 -4 L18 -8", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M22 10 L28 4 L26 -2 L36 -6 L42 0", .solid("#000000", 0), stroke: "#FFC23D", width: 3.7, blur: 2.5),
                    ArtLayer("M22 10 L28 4 L26 -2 L36 -6 L42 0", .solid("#000000", 0), stroke: "#FFC23D", width: 1.2),
                    ArtLayer("M22 10 L28 4 L26 -2 L36 -6 L42 0", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M30 12 L36 8", .solid("#000000", 0), stroke: "#FF5A1F", width: 3.5, blur: 2.5),
                    ArtLayer("M30 12 L36 8", .solid("#000000", 0), stroke: "#FF5A1F", width: 1),
                    ArtLayer("M30 12 L36 8", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "lava.bottom":
            return [
                GearPart(anchor: .thigh, z: .limb, far: true, layers: [
                    ArtLayer("M14 -10 L19 -12 L26 -8 L22 -5 L29 -1 L23 2 L28 7 L21 8 L24 12 L14 10 Z", .linear(["#FFC23D", "#FF5A1F"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M14 -9.5 L14 9.5", .solid("#000000", 0), stroke: "#2A1A16", width: 1.2)
                ])
            ]
        case "lava.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M6 -2 Q-24 -20 -84 -32 L-96 -30 L-88 -26 L-102 -20 L-90 -16 L-100 -10 L-88 -8 L-94 -2 L-84 -4 Q-40 -6 2 8 Z", .solid("#FF5A1F", 0.8), blur: 3),
                    ArtLayer("M6 -2 Q-24 -20 -84 -32 L-96 -30 L-88 -26 L-102 -20 L-90 -16 L-100 -10 L-88 -8 L-94 -2 L-84 -4 Q-40 -6 2 8 Z", .linear(["#7A1C08", "#FF5A1F", "#FFC23D"]), stroke: "#0A0D12", width: 2.6),
                    ArtLayer("M-10 -14 Q-40 -22 -70 -22", .solid("#000000", 0), stroke: "#000000", width: 3),
                    ArtLayer("M4 -2 C6.2 -2 8 -0.2 8 2 C8 4.2 6.2 6 4 6 C1.8 6 0 4.2 0 2 C0 -0.2 1.8 -2 4 -2 Z", .solid("#FFC23D", 1), stroke: "#0A0D12", width: 1.6)
                ])
            ]
        case "frost.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#BFE6FF", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-15.5 -7.5 L-9.5 -7.5 Q-7.5 -7.5 -7.5 -5.5 L-7.5 5.5 Q-7.5 7.5 -9.5 7.5 L-15.5 7.5 Q-17.5 7.5 -17.5 5.5 L-17.5 -5.5 Q-17.5 -7.5 -15.5 -7.5 Z", .linear(["#F2FBFF", "#7FCBFF"]), stroke: "#1D5A8A", width: 1.8),
                    ArtLayer("M-9.5 5 L-12 5.5 L-9.5 1 Z", .solid("#FFFFFF", 0.9)),
                    ArtLayer("M-14 -5 L-15.5 -2", .solid("#000000", 0), stroke: "#FFFFFF", width: 1.2),
                    ArtLayer("M9.5 -7.5 L15.5 -7.5 Q17.5 -7.5 17.5 -5.5 L17.5 5.5 Q17.5 7.5 15.5 7.5 L9.5 7.5 Q7.5 7.5 7.5 5.5 L7.5 -5.5 Q7.5 -7.5 9.5 -7.5 Z", .linear(["#F2FBFF", "#7FCBFF"]), stroke: "#1D5A8A", width: 1.8),
                    ArtLayer("M9.5 5 L12 5.5 L9.5 1 Z", .solid("#FFFFFF", 0.9)),
                    ArtLayer("M14 -5 L15.5 -2", .solid("#000000", 0), stroke: "#FFFFFF", width: 1.2)
                ])
            ]
        case "frost.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-6 -3 Q-8 14 -5 16 L6 16 Q7 8 10 5 Q20 3 21 0 L21 -3 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 2.2),
                    ArtLayer("M-3 -3 L-3 -7 L18 -7 L18 -3 Z", .solid("#9AA4AF", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M-6 -7 L22 -7 Q26 -8 24 -11 L-6 -11 Q-8 -9 -6 -7 Z", .linear(["#FFFFFF", "#4FB8FF"]), stroke: "#1D5A8A", width: 1.6),
                    ArtLayer("M0 13 L4 10 L0 7", .solid("#000000", 0), stroke: "#4FB8FF", width: 1.4),
                    ArtLayer("M-5 13 L5 13 Q7 13 7 15 L7 15 Q7 17 5 17 L-5 17 Q-7 17 -7 15 L-7 15 Q-7 13 -5 13 Z", .solid("#CFEFFF", 1), stroke: "#1D5A8A", width: 1.4)
                ])
            ]
        case "frost.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-8 -7.5 L-3 -7.5 Q-1 -7.5 -1 -5.5 L-1 5.5 Q-1 7.5 -3 7.5 L-8 7.5 Q-10 7.5 -10 5.5 L-10 -5.5 Q-10 -7.5 -8 -7.5 Z", .solid("#FFFFFF", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M1.5 -6.5 C5.4 -6.5 8.5 -3.6 8.5 0 C8.5 3.6 5.4 6.5 1.5 6.5 C-2.4 6.5 -5.5 3.6 -5.5 0 C-5.5 -3.6 -2.4 -6.5 1.5 -6.5 Z", .solid("#CFEFFF", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M4 3 L6.5 1", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4 -1.5 L6.5 -3", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M3 6 L6 13 L8 5 Z", .linear(["#FFFFFF", "#4FB8FF"]), stroke: "#1D5A8A", width: 1.2),
                    ArtLayer("M6 3 L12 8 L10 1 Z", .linear(["#FFFFFF", "#4FB8FF"]), stroke: "#1D5A8A", width: 1.2),
                    ArtLayer("M7 -2 L13 -3 L8 -5 Z", .linear(["#FFFFFF", "#4FB8FF"]), stroke: "#1D5A8A", width: 1.2)
                ])
            ]
        case "frost.top":
            return [
                GearPart(anchor: .torso, z: .over, far: false, layers: [
                    ArtLayer("M48 -16.2 C50.3 -16.2 52.2 -14.3 52.2 -12 C52.2 -9.7 50.3 -7.8 48 -7.8 C45.7 -7.8 43.8 -9.7 43.8 -12 C43.8 -14.3 45.7 -16.2 48 -16.2 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.3),
                    ArtLayer("M49 -12.2 C51.3 -12.2 53.2 -10.3 53.2 -8 C53.2 -5.7 51.3 -3.8 49 -3.8 C46.7 -3.8 44.8 -5.7 44.8 -8 C44.8 -10.3 46.7 -12.2 49 -12.2 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.3),
                    ArtLayer("M49.5 -7.2 C51.8 -7.2 53.7 -5.3 53.7 -3 C53.7 -0.7 51.8 1.2 49.5 1.2 C47.2 1.2 45.3 -0.7 45.3 -3 C45.3 -5.3 47.2 -7.2 49.5 -7.2 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.3),
                    ArtLayer("M49.5 -2.2 C51.8 -2.2 53.7 -0.3 53.7 2 C53.7 4.3 51.8 6.2 49.5 6.2 C47.2 6.2 45.3 4.3 45.3 2 C45.3 -0.3 47.2 -2.2 49.5 -2.2 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.3),
                    ArtLayer("M49 2.8 C51.3 2.8 53.2 4.7 53.2 7 C53.2 9.3 51.3 11.2 49 11.2 C46.7 11.2 44.8 9.3 44.8 7 C44.8 4.7 46.7 2.8 49 2.8 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.3),
                    ArtLayer("M48 7.8 C50.3 7.8 52.2 9.7 52.2 12 C52.2 14.3 50.3 16.2 48 16.2 C45.7 16.2 43.8 14.3 43.8 12 C43.8 9.7 45.7 7.8 48 7.8 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.3)
                ]),
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M22 0 L34 0", .solid("#000000", 0), stroke: "#4FB8FF", width: 1.8),
                    ArtLayer("M24 -5 L32 5", .solid("#000000", 0), stroke: "#4FB8FF", width: 1.8),
                    ArtLayer("M24 5 L32 -5", .solid("#000000", 0), stroke: "#4FB8FF", width: 1.8),
                    ArtLayer("M28 -2 C29.1 -2 30 -1.1 30 0 C30 1.1 29.1 2 28 2 C26.9 2 26 1.1 26 0 C26 -1.1 26.9 -2 28 -2 Z", .solid("#FFFFFF", 1), stroke: "#4FB8FF", width: 1)
                ])
            ]
        case "frost.bottom":
            return [
                GearPart(anchor: .shin, z: .limb, far: true, layers: [
                    ArtLayer("M32 -9.4 C33.9 -9.4 35.4 -7.9 35.4 -6 C35.4 -4.1 33.9 -2.6 32 -2.6 C30.1 -2.6 28.6 -4.1 28.6 -6 C28.6 -7.9 30.1 -9.4 32 -9.4 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.2),
                    ArtLayer("M32 -5.4 C33.9 -5.4 35.4 -3.9 35.4 -2 C35.4 -0.1 33.9 1.4 32 1.4 C30.1 1.4 28.6 -0.1 28.6 -2 C28.6 -3.9 30.1 -5.4 32 -5.4 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.2),
                    ArtLayer("M32 -1.4 C33.9 -1.4 35.4 0.1 35.4 2 C35.4 3.9 33.9 5.4 32 5.4 C30.1 5.4 28.6 3.9 28.6 2 C28.6 0.1 30.1 -1.4 32 -1.4 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.2),
                    ArtLayer("M32 2.6 C33.9 2.6 35.4 4.1 35.4 6 C35.4 7.9 33.9 9.4 32 9.4 C30.1 9.4 28.6 7.9 28.6 6 C28.6 4.1 30.1 2.6 32 2.6 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.2),
                    ArtLayer("M-3 5 L2 13 L6 5 L2 3 Z", .linear(["#FFFFFF", "#4FB8FF"]), stroke: "#1D5A8A", width: 1.4)
                ])
            ]
        case "frost.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M6 -2 Q-24 -20 -84 -32 L-92 -30 L-86 -27 L-98 -23 L-86 -19 L-95 -14 L-85 -11 L-92 -6 L-84 -4 Q-40 -6 2 8 Z", .linear(["#FFFFFF", "#9ED8FF", "#4FB8FF"]), stroke: "#1D5A8A", width: 2.6),
                    ArtLayer("M-30 -14 L-44 -18", .solid("#000000", 0), stroke: "#FFFFFF", width: 1.6),
                    ArtLayer("M-37 -10 L-37 -22", .solid("#000000", 0), stroke: "#FFFFFF", width: 1.6),
                    ArtLayer("M-10 -16 Q-40 -22 -70 -24", .solid("#000000", 0), stroke: "#1D5A8A", width: 2),
                    ArtLayer("M-2 -6 C0.2 -6 2 -4.2 2 -2 C2 0.2 0.2 2 -2 2 C-4.2 2 -6 0.2 -6 -2 C-6 -4.2 -4.2 -6 -2 -6 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.2),
                    ArtLayer("M2 -8 C4.2 -8 6 -6.2 6 -4 C6 -1.8 4.2 0 2 0 C-0.2 0 -2 -1.8 -2 -4 C-2 -6.2 -0.2 -8 2 -8 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.2),
                    ArtLayer("M6 -10 C8.2 -10 10 -8.2 10 -6 C10 -3.8 8.2 -2 6 -2 C3.8 -2 2 -3.8 2 -6 C2 -8.2 3.8 -10 6 -10 Z", .solid("#FFFFFF", 1), stroke: "#1D5A8A", width: 1.2)
                ])
            ]
        case "gold.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#F2B630", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-13 -8 L-11.5 -8 Q-8 -8 -8 -4.5 L-8 4.5 Q-8 8 -11.5 8 L-13 8 Q-16.5 8 -16.5 4.5 L-16.5 -4.5 Q-16.5 -8 -13 -8 Z", .linear(["#FFF1B8", "#F2B630", "#8A5A00"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-12.2 3.2 L-13 1.1 L-15.2 1 L-13.5 -0.4 L-14.1 -2.6 L-12.2 -1.4 L-10.3 -2.6 L-10.9 -0.4 L-9.2 1 L-11.4 1.1 Z", .solid("#FFFFFF", 1)),
                    ArtLayer("M11.5 -8 L13 -8 Q16.5 -8 16.5 -4.5 L16.5 4.5 Q16.5 8 13 8 L11.5 8 Q8 8 8 4.5 L8 -4.5 Q8 -8 11.5 -8 Z", .linear(["#FFF1B8", "#F2B630", "#8A5A00"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M12.2 3.2 L11.4 1.1 L9.2 1 L10.9 -0.4 L10.3 -2.6 L12.2 -1.4 L14.1 -2.6 L13.5 -0.4 L15.2 1 L13 1.1 Z", .solid("#FFFFFF", 1))
                ])
            ]
        case "gold.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-6 -3 Q-8 16 -5 19 L7 19 Q7 8 10 6 Q21 4 22 -1 L22 -3 Z", .linear(["#FFF1B8", "#F2B630"]), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-7 -3 L22 -3 Q24.5 -4.5 22 -6 L-6 -6 Q-8.5 -5.5 -7 -3 Z", .solid("#8A5A00", 1), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M-5 13 Q-16 22 -22 18 Q-15 17 -17 13 Q-12 15 -10 10 Z", .linear(["#FFFFFF", "#FFF1B8"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-5 17 L6 17 Q8 17 8 19 L8 19 Q8 21 6 21 L-5 21 Q-7 21 -7 19 L-7 19 Q-7 17 -5 17 Z", .solid("#F2B630", 1), stroke: "#0A0D12", width: 1.5)
                ]),
                GearPart(anchor: .shin, z: .limb, far: true, layers: [
                    ArtLayer("M24 -7.5 L38 -7.5 L38 7.5 L24 7.5 Z", .linear(["#FFF1B8", "#F2B630"]), stroke: "#0A0D12", width: 1.8)
                ])
            ]
        case "gold.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-11 -8 L-6 -8 Q-4 -8 -4 -6 L-4 6 Q-4 8 -6 8 L-11 8 Q-13 8 -13 6 L-13 -6 Q-13 -8 -11 -8 Z", .solid("#FFFFFF", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-11 -7 L-11 7", .solid("#000000", 0), stroke: "#F2B630", width: 1.4),
                    ArtLayer("M-5 -9 Q2 -12 9 -9 Q15 -5 14 2 Q13 10 4 11 Q-4 11 -5 6 Z", .linear(["#FFF1B8", "#F2B630", "#8A5A00"]), stroke: "#0A0D12", width: 2.4),
                    ArtLayer("M-3 6 Q2 3 6 7", .solid("#000000", 0), stroke: "#0A0D12", width: 1.4),
                    ArtLayer("M4 -7 C5.9 -7 7.5 -6.1 7.5 -5 C7.5 -3.9 5.9 -3 4 -3 C2.1 -3 0.5 -3.9 0.5 -5 C0.5 -6.1 2.1 -7 4 -7 Z", .solid("#FFFFFF", 0.55))
                ])
            ]
        case "gold.top":
            return [
                GearPart(anchor: .torso, z: .over, far: false, layers: [
                    ArtLayer("M48 -10 L40 -4 L30 4 L26 12", .solid("#000000", 0), stroke: "#8A5A00", width: 3.8),
                    ArtLayer("M48 -10 L40 -4 L30 4 L26 12", .solid("#000000", 0), stroke: "#F2B630", width: 2.2),
                    ArtLayer("M24 6.5 C27.6 6.5 30.5 9.4 30.5 13 C30.5 16.6 27.6 19.5 24 19.5 C20.4 19.5 17.5 16.6 17.5 13 C17.5 9.4 20.4 6.5 24 6.5 Z", .linear(["#FFF1B8", "#F2B630", "#8A5A00"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M24 16.6 L23.1 14.3 L20.6 14.1 L22.5 12.5 L21.9 10.1 L24 11.4 L26.1 10.1 L25.5 12.5 L27.4 14.1 L24.9 14.3 Z", .solid("#FFFFFF", 1))
                ])
            ]
        case "gold.bottom":
            return [
                GearPart(anchor: .thigh, z: .limb, far: true, layers: [
                    ArtLayer("M-4 -11 L22 -12 L23 11 L-4 11 Z", .linear(["#C8302C", "#8A1A18"]), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M2 -11 L21 -11.5", .solid("#000000", 0), stroke: "#F2B630", width: 2)
                ]),
                GearPart(anchor: .torso, z: .over, far: false, layers: [
                    ArtLayer("M1 -12 L5 -12 Q7 -12 7 -10 L7 10 Q7 12 5 12 L1 12 Q-1 12 -1 10 L-1 -10 Q-1 -12 1 -12 Z", .solid("#7A1414", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M3 1.5 C6.9 1.5 10 4.9 10 9 C10 13.1 6.9 16.5 3 16.5 C-0.9 16.5 -4 13.1 -4 9 C-4 4.9 -0.9 1.5 3 1.5 Z", .linear(["#FFF1B8", "#F2B630", "#8A5A00"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M3 13 L1.9 10.5 L-0.8 10.2 L1.3 8.4 L0.6 5.8 L3 7.2 L5.4 5.8 L4.7 8.4 L6.8 10.2 L4.1 10.5 Z", .solid("#C8302C", 1)),
                    ArtLayer("M3 -7.4 C4.3 -7.4 5.4 -6.3 5.4 -5 C5.4 -3.7 4.3 -2.6 3 -2.6 C1.7 -2.6 0.6 -3.7 0.6 -5 C0.6 -6.3 1.7 -7.4 3 -7.4 Z", .solid("#F2B630", 1), stroke: "#0A0D12", width: 1)
                ])
            ]
        case "gold.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M6 -2 Q-24 -20 -84 -32 L-90 -30 Q-92 -16 -84 -4 Q-40 -6 2 8 Z", .linear(["#E0403A", "#C8302C", "#7A1414"]), stroke: "#0A0D12", width: 2.6),
                    ArtLayer("M-84 -32 L-90 -30 Q-92 -16 -84 -4 L-78 -5 Q-84 -16 -80 -29 Z", .solid("#FFFFFF", 1), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M-85 -22.4 L-86 -24 L-85 -25.6 L-84 -24 Z", .solid("#0A0D12", 1)),
                    ArtLayer("M-86 -14.4 L-87 -16 L-86 -17.6 L-85 -16 Z", .solid("#0A0D12", 1)),
                    ArtLayer("M-83 -7.4 L-84 -9 L-83 -10.6 L-82 -9 Z", .solid("#0A0D12", 1)),
                    ArtLayer("M-12 -16 Q-44 -24 -72 -26", .solid("#000000", 0), stroke: "#000000", width: 3),
                    ArtLayer("M5 -3 C8.3 -3 11 -0.8 11 2 C11 4.8 8.3 7 5 7 C1.7 7 -1 4.8 -1 2 C-1 -0.8 1.7 -3 5 -3 Z", .linear(["#FFF1B8", "#F2B630"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M5 0 C6.1 0 7 0.9 7 2 C7 3.1 6.1 4 5 4 C3.9 4 3 3.1 3 2 C3 0.9 3.9 0 5 0 Z", .solid("#C8302C", 1))
                ])
            ]
        case "shadow.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#2A2236", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-12 -8 C-7.6 -8 -4 -4.4 -4 0 C-4 4.4 -7.6 8 -12 8 C-16.4 8 -20 4.4 -20 0 C-20 -4.4 -16.4 -8 -12 -8 Z", .solid("#9B5CFF", 0.8), blur: 3),
                    ArtLayer("M-12 -7 C-8.1 -7 -5 -3.9 -5 0 C-5 3.9 -8.1 7 -12 7 C-15.9 7 -19 3.9 -19 0 C-19 -3.9 -15.9 -7 -12 -7 Z", .linear(["#3A2A55", "#0A0610"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-12 -2.6 C-10.6 -2.6 -9.4 -1.4 -9.4 0 C-9.4 1.4 -10.6 2.6 -12 2.6 C-13.4 2.6 -14.6 1.4 -14.6 0 C-14.6 -1.4 -13.4 -2.6 -12 -2.6 Z", .solid("#E2D4FF", 1)),
                    ArtLayer("M-12 -4.6 C-9.5 -4.6 -7.4 -2.5 -7.4 0 C-7.4 2.5 -9.5 4.6 -12 4.6 C-14.5 4.6 -16.6 2.5 -16.6 0 C-16.6 -2.5 -14.5 -4.6 -12 -4.6 Z", .solid("#000000", 0), stroke: "#9B5CFF", width: 1),
                    ArtLayer("M12 -8 C16.4 -8 20 -4.4 20 0 C20 4.4 16.4 8 12 8 C7.6 8 4 4.4 4 0 C4 -4.4 7.6 -8 12 -8 Z", .solid("#9B5CFF", 0.8), blur: 3),
                    ArtLayer("M12 -7 C15.9 -7 19 -3.9 19 0 C19 3.9 15.9 7 12 7 C8.1 7 5 3.9 5 0 C5 -3.9 8.1 -7 12 -7 Z", .linear(["#3A2A55", "#0A0610"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M12 -2.6 C13.4 -2.6 14.6 -1.4 14.6 0 C14.6 1.4 13.4 2.6 12 2.6 C10.6 2.6 9.4 1.4 9.4 0 C9.4 -1.4 10.6 -2.6 12 -2.6 Z", .solid("#E2D4FF", 1)),
                    ArtLayer("M12 -4.6 C14.5 -4.6 16.6 -2.5 16.6 0 C16.6 2.5 14.5 4.6 12 4.6 C9.5 4.6 7.4 2.5 7.4 0 C7.4 -2.5 9.5 -4.6 12 -4.6 Z", .solid("#000000", 0), stroke: "#9B5CFF", width: 1)
                ])
            ]
        case "shadow.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-6 -3 Q-8 10 -4 13 L5 13 Q9 6 13 4 Q16 3 17 1 Q19 4 22 1 L22 -3 Z", .solid("#120E1A", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M16.5 1 L16.5 -3", .solid("#000000", 0), stroke: "#3A2A55", width: 1.4),
                    ArtLayer("M-5 10 L5 6", .solid("#000000", 0), stroke: "#9B5CFF", width: 1.6),
                    ArtLayer("M-5 5 L7 2", .solid("#000000", 0), stroke: "#9B5CFF", width: 1.6),
                    ArtLayer("M-7 -3 L22 -3 Q24.5 -4.5 22 -5 L-6 -5 Q-8.5 -5.166666666666667 -7 -3 Z", .solid("#0A0610", 1), stroke: "#0A0D12", width: 1.8)
                ])
            ]
        case "shadow.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-8 -7 L-2 -7 Q0 -7 0 -5 L0 5 Q0 7 -2 7 L-8 7 Q-10 7 -10 5 L-10 -5 Q-10 -7 -8 -7 Z", .solid("#1A1424", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M1.5 -6 C5.1 -6 8 -3.3 8 0 C8 3.3 5.1 6 1.5 6 C-2.1 6 -5 3.3 -5 0 C-5 -3.3 -2.1 -6 1.5 -6 Z", .solid("#1A1424", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M4 3 L6.5 1", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4 -1.5 L6.5 -3", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M5 -5.5 Q16 -7 22 -1 Q15 -3 5 -2.5 Z", .linear(["#E2D4FF", "#9B5CFF"]), stroke: "#0A0D12", width: 1.4),
                    ArtLayer("M5 -1.5 Q16 -3 22 3 Q15 1 5 1.5 Z", .linear(["#E2D4FF", "#9B5CFF"]), stroke: "#0A0D12", width: 1.4),
                    ArtLayer("M5 2.5 Q16 1 22 7 Q15 5 5 5.5 Z", .linear(["#E2D4FF", "#9B5CFF"]), stroke: "#0A0D12", width: 1.4)
                ])
            ]
        case "shadow.top":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M2 -6 Q-6 -24 -2 -40 Q4 -30 6 -22 Q8 -14 6 -6 Z", .linear(["#9B5CFF", "#4A2A80"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M0 -8 Q-12 -20 -12 -34 Q-4 -26 4 -10 Z", .linear(["#9B5CFF", "#2A1A44"]), stroke: "#0A0D12", width: 1.6)
                ]),
                GearPart(anchor: .torso, z: .over, far: false, layers: [
                    ArtLayer("M48 -14 L49 -14 Q53 -14 53 -10 L53 10 Q53 14 49 14 L48 14 Q44 14 44 10 L44 -10 Q44 -14 48 -14 Z", .linear(["#9B5CFF", "#4A2A80"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M46 -12 L46 12", .solid("#000000", 0), stroke: "#E2D4FF", width: 1)
                ]),
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M42 -10 L8 10", .solid("#000000", 0), stroke: "#2A2236", width: 4),
                    ArtLayer("M42 -10 L8 10", .solid("#000000", 0), stroke: "#9B5CFF", width: 1.2)
                ])
            ]
        case "shadow.bottom":
            return [
                GearPart(anchor: .shin, z: .limb, far: true, layers: [
                    ArtLayer("M6 -7.5 L10 -7.5 L7 7.5 L3 7.5 Z", .solid("#9B5CFF", 0.85), stroke: "#0A0D12", width: 1),
                    ArtLayer("M13 -7.5 L17 -7.5 L14 7.5 L10 7.5 Z", .solid("#9B5CFF", 0.85), stroke: "#0A0D12", width: 1),
                    ArtLayer("M20 -7.5 L24 -7.5 L21 7.5 L17 7.5 Z", .solid("#9B5CFF", 0.85), stroke: "#0A0D12", width: 1),
                    ArtLayer("M27 -7.5 L31 -7.5 L28 7.5 L24 7.5 Z", .solid("#9B5CFF", 0.85), stroke: "#0A0D12", width: 1)
                ])
            ]
        case "shadow.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M6 -2 Q-24 -20 -84 -32 L-100 -34 L-90 -28 L-98 -22 L-86 -18 L-102 -12 L-88 -9 L-94 -3 L-84 -4 Q-40 -6 2 8 Z", .solid("#9B5CFF", 0.6), blur: 3),
                    ArtLayer("M6 -2 Q-24 -20 -84 -32 L-100 -34 L-90 -28 L-98 -22 L-86 -18 L-102 -12 L-88 -9 L-94 -3 L-84 -4 Q-40 -6 2 8 Z", .linear(["#2A1A44", "#120A1C"]), stroke: "#0A0D12", width: 2.6),
                    ArtLayer("M-10 -14 Q-40 -22 -76 -24", .solid("#000000", 0), stroke: "#9B5CFF", width: 1.4)
                ])
            ]
        case "titan.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#5A6676", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-8 -6 L-10 -8 L-15 -8 L-17 -5 L-17 5 L-15 8 L-10 8 L-8 6 Z", .linear(["#C2CBD6", "#5A6676"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-12.5 -5 L-12.5 -5 Q-11 -5 -11 -3.5 L-11 3.5 Q-11 5 -12.5 5 L-12.5 5 Q-14 5 -14 3.5 L-14 -3.5 Q-14 -5 -12.5 -5 Z", .solid("#000000", 0), stroke: "#31F2D4", width: 3.5, blur: 2.5),
                    ArtLayer("M-12.5 -5 L-12.5 -5 Q-11 -5 -11 -3.5 L-11 3.5 Q-11 5 -12.5 5 L-12.5 5 Q-14 5 -14 3.5 L-14 -3.5 Q-14 -5 -12.5 -5 Z", .solid("#000000", 0), stroke: "#31F2D4", width: 1),
                    ArtLayer("M-12.5 -5 L-12.5 -5 Q-11 -5 -11 -3.5 L-11 3.5 Q-11 5 -12.5 5 L-12.5 5 Q-14 5 -14 3.5 L-14 -3.5 Q-14 -5 -12.5 -5 Z", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M8 -6 L10 -8 L15 -8 L17 -5 L17 5 L15 8 L10 8 L8 6 Z", .linear(["#C2CBD6", "#5A6676"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M12.5 -5 L12.5 -5 Q14 -5 14 -3.5 L14 3.5 Q14 5 12.5 5 L12.5 5 Q11 5 11 3.5 L11 -3.5 Q11 -5 12.5 -5 Z", .solid("#000000", 0), stroke: "#31F2D4", width: 3.5, blur: 2.5),
                    ArtLayer("M12.5 -5 L12.5 -5 Q14 -5 14 -3.5 L14 3.5 Q14 5 12.5 5 L12.5 5 Q11 5 11 3.5 L11 -3.5 Q11 -5 12.5 -5 Z", .solid("#000000", 0), stroke: "#31F2D4", width: 1),
                    ArtLayer("M12.5 -5 L12.5 -5 Q14 -5 14 -3.5 L14 3.5 Q14 5 12.5 5 L12.5 5 Q11 5 11 3.5 L11 -3.5 Q11 -5 12.5 -5 Z", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "titan.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-8 -12 Q2 -26 12 -12 Z", .linear(["#FFFFFF", "#31F2D4"]), blur: 3),
                    ArtLayer("M-4 -10 Q2 -20 8 -10 Z", .solid("#FFFFFF", 0.9)),
                    ArtLayer("M-7 -3 Q-9 14 -6 16 L7 16 Q7 8 11 6 Q22 4 23 -1 L23 -4 Z", .linear(["#C2CBD6", "#5A6676"]), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-4 -9 L18 -9 Q20 -9 20 -7 L20 -5 Q20 -3 18 -3 L-4 -3 Q-6 -3 -6 -5 L-6 -7 Q-6 -9 -4 -9 Z", .solid("#2A3340", 1), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M-2 -6 L16 -6", .solid("#000000", 0), stroke: "#31F2D4", width: 3.7, blur: 2.5),
                    ArtLayer("M-2 -6 L16 -6", .solid("#000000", 0), stroke: "#31F2D4", width: 1.2),
                    ArtLayer("M-2 -6 L16 -6", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M8 4 L13 2", .solid("#000000", 0), stroke: "#0A0D12", width: 1.2)
                ])
            ]
        case "titan.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-9 -8.5 L-2 -8.5 Q1 -8.5 1 -5.5 L1 5.5 Q1 8.5 -2 8.5 L-9 8.5 Q-12 8.5 -12 5.5 L-12 -5.5 Q-12 -8.5 -9 -8.5 Z", .linear(["#C2CBD6", "#5A6676"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-6 -8 L-6 8", .solid("#000000", 0), stroke: "#0A0D12", width: 1.2),
                    ArtLayer("M3 -7.5 L7 -7.5 Q11 -7.5 11 -3.5 L11 3.5 Q11 7.5 7 7.5 L3 7.5 Q-1 7.5 -1 3.5 L-1 -3.5 Q-1 -7.5 3 -7.5 Z", .linear(["#C2CBD6", "#8C98A8"]), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M3 -5 L3 5", .solid("#000000", 0), stroke: "#31F2D4", width: 3.7, blur: 2.5),
                    ArtLayer("M3 -5 L3 5", .solid("#000000", 0), stroke: "#31F2D4", width: 1.2),
                    ArtLayer("M3 -5 L3 5", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M-9 -2 C-7.9 -2 -7 -1.1 -7 0 C-7 1.1 -7.9 2 -9 2 C-10.1 2 -11 1.1 -11 0 C-11 -1.1 -10.1 -2 -9 -2 Z", .solid("#31F2D4", 1), stroke: "#0A0D12", width: 1)
                ])
            ]
        case "titan.top":
            return [
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M28 14.4 L46 16.5 L48 -4 L30 -6 Z", .linear(["#C2CBD6", "#5A6676"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M6 2 L8 2 Q10 2 10 4 L10 9.5 Q10 11.5 8 11.5 L6 11.5 Q4 11.5 4 9.5 L4 4 Q4 2 6 2 Z", .solid("#8C98A8", 1), stroke: "#0A0D12", width: 1.4),
                    ArtLayer("M13 2 L15 2 Q17 2 17 4 L17 10.3 Q17 12.3 15 12.3 L13 12.3 Q11 12.3 11 10.3 L11 4 Q11 2 13 2 Z", .solid("#8C98A8", 1), stroke: "#0A0D12", width: 1.4),
                    ArtLayer("M20 2 L22 2 Q24 2 24 4 L24 11.2 Q24 13.2 22 13.2 L20 13.2 Q18 13.2 18 11.2 L18 4 Q18 2 20 2 Z", .solid("#8C98A8", 1), stroke: "#0A0D12", width: 1.4),
                    ArtLayer("M24 -8 L24 8", .solid("#000000", 0), stroke: "#31F2D4", width: 3.3, blur: 2.5),
                    ArtLayer("M24 -8 L24 8", .solid("#000000", 0), stroke: "#31F2D4", width: 0.8),
                    ArtLayer("M24 -8 L24 8", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "titan.bottom":
            return [
                GearPart(anchor: .thigh, z: .limb, far: true, layers: [
                    ArtLayer("M9 -2 L23 -2 Q26 -2 26 1 L26 6 Q26 9 23 9 L9 9 Q6 9 6 6 L6 1 Q6 -2 9 -2 Z", .linear(["#C2CBD6", "#5A6676"]), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M10 3 L22 3", .solid("#000000", 0), stroke: "#31F2D4", width: 3.3, blur: 2.5),
                    ArtLayer("M10 3 L22 3", .solid("#000000", 0), stroke: "#31F2D4", width: 0.8),
                    ArtLayer("M10 3 L22 3", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ]),
                GearPart(anchor: .shin, z: .limb, far: true, layers: [
                    ArtLayer("M-4 3 Q2 14 9 3 L7 -1 L-2 -1 Z", .linear(["#E6EBF0", "#8C98A8"]), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M2.5 3.2 C3.5 3.2 4.3 4 4.3 5 C4.3 6 3.5 6.8 2.5 6.8 C1.5 6.8 0.7 6 0.7 5 C0.7 4 1.5 3.2 2.5 3.2 Z", .solid("#31F2D4", 1))
                ])
            ]
        case "titan.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M-33 -22 L-13 -22 Q-10 -22 -10 -19 L-10 -16 Q-10 -13 -13 -13 L-33 -13 Q-36 -13 -36 -16 L-36 -19 Q-36 -22 -33 -22 Z", .linear(["#C2CBD6", "#5A6676"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-33 -30 L-13 -30 Q-10 -30 -10 -27 L-10 -24 Q-10 -21 -13 -21 L-33 -21 Q-36 -21 -36 -24 L-36 -27 Q-36 -30 -33 -30 Z", .linear(["#C2CBD6", "#5A6676"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-27 -28 L-13 -28 Q-10 -28 -10 -25 L-10 -13 Q-10 -10 -13 -10 L-27 -10 Q-30 -10 -30 -13 L-30 -25 Q-30 -28 -27 -28 Z", .solid("#5A6676", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-36 -17 Q-58 -14 -36 -11 Z", .solid("#31F2D4", 0.85), blur: 3),
                    ArtLayer("M-36 -25 Q-58 -22 -36 -19 Z", .solid("#31F2D4", 0.85), blur: 3),
                    ArtLayer("M-36 -16 Q-48 -14 -36 -12 Z", .solid("#FFFFFF", 1)),
                    ArtLayer("M-36 -24 Q-48 -22 -36 -20 Z", .solid("#FFFFFF", 1)),
                    ArtLayer("M-16 -14 L-16 -22", .solid("#000000", 0), stroke: "#31F2D4", width: 3.5, blur: 2.5),
                    ArtLayer("M-16 -14 L-16 -22", .solid("#000000", 0), stroke: "#31F2D4", width: 1),
                    ArtLayer("M-16 -14 L-16 -22", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "night.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#2A303A", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-14.5 -7.5 L-9.5 -7.5 Q-8 -7.5 -8 -6 L-8 6 Q-8 7.5 -9.5 7.5 L-14.5 7.5 Q-16 7.5 -16 6 L-16 -6 Q-16 -7.5 -14.5 -7.5 Z", .solid("#2A303A", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-13 -7.5 L-11 -7.5 Q-11 -7.5 -11 -7.5 L-11 7.5 Q-11 7.5 -11 7.5 L-13 7.5 Q-13 7.5 -13 7.5 L-13 -7.5 Q-13 -7.5 -13 -7.5 Z", .solid("#FF8A1F", 1)),
                    ArtLayer("M9.5 -7.5 L14.5 -7.5 Q16 -7.5 16 -6 L16 6 Q16 7.5 14.5 7.5 L9.5 7.5 Q8 7.5 8 6 L8 -6 Q8 -7.5 9.5 -7.5 Z", .solid("#2A303A", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M11 -7.5 L13 -7.5 Q13 -7.5 13 -7.5 L13 7.5 Q13 7.5 13 7.5 L11 7.5 Q11 7.5 11 7.5 L11 -7.5 Q11 -7.5 11 -7.5 Z", .solid("#FF8A1F", 1))
                ])
            ]
        case "night.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-7 -3 Q-9 14 -6 17 L6 17 Q6 8 10 6 Q21 4 22 -1 L22 -3 Z", .solid("#232A36", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-7 -3 L22 -3 Q24.5 -4.5 22 -7.5 L-6 -7.5 Q-8.5 -6 -7 -3 Z", .solid("#0E1218", 1), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M-6 -7.5 L-3 -5.5 L0 -7.5 L3 -5.5 L6 -7.5 L9 -5.5 L12 -7.5 L15 -5.5 L18 -7.5", .solid("#000000", 0), stroke: "#3B4558", width: 1.2),
                    ArtLayer("M-6 5 L5 5 Q6 5 6 6 L6 6.6 Q6 7.6 5 7.6 L-6 7.6 Q-7 7.6 -7 6.6 L-7 6 Q-7 5 -6 5 Z", .solid("#FF8A1F", 1), stroke: "#0A0D12", width: 1),
                    ArtLayer("M-6 11 L5 11 Q6 11 6 12 L6 12.6 Q6 13.6 5 13.6 L-6 13.6 Q-7 13.6 -7 12.6 L-7 12 Q-7 11 -6 11 Z", .solid("#3B4558", 1), stroke: "#0A0D12", width: 1)
                ])
            ]
        case "night.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-14 -7.5 L-3 -7.5 Q-1 -7.5 -1 -5.5 L-1 5.5 Q-1 7.5 -3 7.5 L-14 7.5 Q-16 7.5 -16 5.5 L-16 -5.5 Q-16 -7.5 -14 -7.5 Z", .solid("#2A303A", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-14 -7 L-17 -14 L-11 -7 Z", .solid("#3B4558", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M-9 -7 L-12 -14 L-6 -7 Z", .solid("#3B4558", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M-4 -7 L-7 -14 L-1 -7 Z", .solid("#3B4558", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M1.5 -6 C5.1 -6 8 -3.3 8 0 C8 3.3 5.1 6 1.5 6 C-2.1 6 -5 3.3 -5 0 C-5 -3.3 -2.1 -6 1.5 -6 Z", .solid("#1C2230", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M4 3 L6.5 1", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4 -1.5 L6.5 -3", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4.5 -5.5 L5.5 -5.5 Q7 -5.5 7 -4 L7 4 Q7 5.5 5.5 5.5 L4.5 5.5 Q3 5.5 3 4 L3 -4 Q3 -5.5 4.5 -5.5 Z", .solid("#FF8A1F", 1), stroke: "#0A0D12", width: 1.2)
                ])
            ]
        case "night.top":
            return [
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M46 8 L6 -10", .solid("#000000", 0), stroke: "#0A0D12", width: 5),
                    ArtLayer("M46 8 L6 -10", .solid("#000000", 0), stroke: "#3B4558", width: 3),
                    ArtLayer("M3.5 4 L9.5 4 Q11 4 11 5.5 L11 10.5 Q11 12 9.5 12 L3.5 12 Q2 12 2 10.5 L2 5.5 Q2 4 3.5 4 Z", .solid("#2A303A", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M3.5 -6 L9.5 -6 Q11 -6 11 -4.5 L11 0.5 Q11 2 9.5 2 L3.5 2 Q2 2 2 0.5 L2 -4.5 Q2 -6 3.5 -6 Z", .solid("#2A303A", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M1 -12 L3 -12 Q4 -12 4 -11 L4 11 Q4 12 3 12 L1 12 Q0 12 0 11 L0 -11 Q0 -12 1 -12 Z", .solid("#FF8A1F", 1), stroke: "#0A0D12", width: 1),
                    ArtLayer("M31.5 6 L36.5 6 Q38 6 38 7.5 L38 11.5 Q38 13 36.5 13 L31.5 13 Q30 13 30 11.5 L30 7.5 Q30 6 31.5 6 Z", .solid("#2A303A", 1), stroke: "#0A0D12", width: 1.5)
                ])
            ]
        case "night.bottom":
            return [
                GearPart(anchor: .thigh, z: .limb, far: true, layers: [
                    ArtLayer("M14 -6 L22 -6 Q24 -6 24 -4 L24 3 Q24 5 22 5 L14 5 Q12 5 12 3 L12 -4 Q12 -6 14 -6 Z", .solid("#141922", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M12 -6.5 L14 -6.5 Q15 -6.5 15 -5.5 L15 4.5 Q15 5.5 14 5.5 L12 5.5 Q11 5.5 11 4.5 L11 -5.5 Q11 -6.5 12 -6.5 Z", .solid("#2A303A", 1), stroke: "#0A0D12", width: 1.2),
                    ArtLayer("M13 2 C13.6 2 14 2.4 14 3 C14 3.6 13.6 4 13 4 C12.4 4 12 3.6 12 3 C12 2.4 12.4 2 13 2 Z", .solid("#FF8A1F", 1))
                ]),
                GearPart(anchor: .shin, z: .limb, far: true, layers: [
                    ArtLayer("M0 1 L5 1 Q8 1 8 4 L8 6 Q8 9 5 9 L0 9 Q-3 9 -3 6 L-3 4 Q-3 1 0 1 Z", .solid("#3B4558", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M0 5 L5 5", .solid("#000000", 0), stroke: "#FF8A1F", width: 1.4)
                ])
            ]
        case "night.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M6 -2 Q-24 -20 -84 -32 Q-80 -26 -92 -24 Q-82 -18 -90 -12 Q-80 -10 -88 -2 Q-82 -4 -84 -4 Q-40 -6 2 8 Z", .linear(["#232A36", "#0E1218"]), stroke: "#0A0D12", width: 2.6),
                    ArtLayer("M2 6 Q-40 -4 -84 -4 Q-40 -8 2 3 Z", .solid("#FF8A1F", 1)),
                    ArtLayer("M-10 -14 Q-40 -20 -74 -24", .solid("#000000", 0), stroke: "#3B4558", width: 2),
                    ArtLayer("M2 -2 L5 -2 Q7 -2 7 0 L7 3 Q7 5 5 5 L2 5 Q0 5 0 3 L0 0 Q0 -2 2 -2 Z", .solid("#FF8A1F", 1), stroke: "#0A0D12", width: 1.4)
                ])
            ]
        case "dawn.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#F2B630", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-2.5 0 L-6 2.5 L-5.3 6.7 L-9.5 6 L-12 9.5 L-14.5 6 L-18.7 6.7 L-18 2.5 L-21.5 0 L-18 -2.5 L-18.7 -6.7 L-14.5 -6 L-12 -9.5 L-9.5 -6 L-5.3 -6.7 L-6 -2.5 Z", .solid("#E0A21B", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M-12 -5.5 C-9 -5.5 -6.5 -3 -6.5 0 C-6.5 3 -9 5.5 -12 5.5 C-15 5.5 -17.5 3 -17.5 0 C-17.5 -3 -15 -5.5 -12 -5.5 Z", .linear(["#FFFFFF", "#E9EEF5"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M21.5 0 L18 2.5 L18.7 6.7 L14.5 6 L12 9.5 L9.5 6 L5.3 6.7 L6 2.5 L2.5 0 L6 -2.5 L5.3 -6.7 L9.5 -6 L12 -9.5 L14.5 -6 L18.7 -6.7 L18 -2.5 Z", .solid("#E0A21B", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M12 -5.5 C15 -5.5 17.5 -3 17.5 0 C17.5 3 15 5.5 12 5.5 C9 5.5 6.5 3 6.5 0 C6.5 -3 9 -5.5 12 -5.5 Z", .linear(["#FFFFFF", "#E9EEF5"]), stroke: "#0A0D12", width: 1.6)
                ])
            ]
        case "dawn.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-7 -3 Q-8 10 -6 12 L7 12 Q7 8 10 6 Q21 4 22 -1 L22 -3 Z", .solid("#2E6BFF", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-7 -3 L22 -3 Q24.5 -4.5 22 -6 L-6 -6 Q-8.5 -5.5 -7 -3 Z", .solid("#1A3F99", 1), stroke: "#0A0D12", width: 1.8)
                ]),
                GearPart(anchor: .shin, z: .limb, far: true, layers: [
                    ArtLayer("M14 -8 L38 -7.5 L38 7.5 L14 8 Q12 0 14 -8 Z", .solid("#2E6BFF", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M14 -9 L15 -9 Q17 -9 17 -7 L17 7 Q17 9 15 9 L14 9 Q12 9 12 7 L12 -7 Q12 -9 14 -9 Z", .solid("#E0A21B", 1), stroke: "#0A0D12", width: 1.6)
                ])
            ]
        case "dawn.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-16 -8 L-1 -7 L-1 7 L-16 8 Q-18 0 -16 -8 Z", .solid("#E0A21B", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-15.5 -9 L-14.5 -9 Q-13 -9 -13 -7.5 L-13 7.5 Q-13 9 -14.5 9 L-15.5 9 Q-17 9 -17 7.5 L-17 -7.5 Q-17 -9 -15.5 -9 Z", .solid("#FFFFFF", 1), stroke: "#0A0D12", width: 1.4),
                    ArtLayer("M-8 4.5 L-9.2 1.6 L-12.3 1.4 L-9.9 -0.6 L-10.6 -3.6 L-8 -2 L-5.4 -3.6 L-6.1 -0.6 L-3.7 1.4 L-6.8 1.6 Z", .solid("#FFFFFF", 1), stroke: "#0A0D12", width: 1),
                    ArtLayer("M1.5 -6 C5.1 -6 8 -3.3 8 0 C8 3.3 5.1 6 1.5 6 C-2.1 6 -5 3.3 -5 0 C-5 -3.3 -2.1 -6 1.5 -6 Z", .solid("#2E6BFF", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M4 3 L6.5 1", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4 -1.5 L6.5 -3", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1)
                ])
            ]
        case "dawn.top":
            return [
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M2 -11 L4 -11 Q6 -11 6 -9 L6 9 Q6 11 4 11 L2 11 Q0 11 0 9 L0 -9 Q0 -11 2 -11 Z", .linear(["#FFF1B8", "#E0A21B"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M2 6 L4 6 Q5.5 6 5.5 7.5 L5.5 10.5 Q5.5 12 4 12 L2 12 Q0.5 12 0.5 10.5 L0.5 7.5 Q0.5 6 2 6 Z", .solid("#2E6BFF", 1), stroke: "#0A0D12", width: 1.2)
                ])
            ]
        case "dawn.bottom":
            return [
                GearPart(anchor: .thigh, z: .limb, far: true, layers: [
                    ArtLayer("M-4 -10.5 L8 -10 L10 0 L8 10 L-4 10.5 Z", .linear(["#FFF1B8", "#E0A21B"]), stroke: "#0A0D12", width: 2)
                ]),
                GearPart(anchor: .torso, z: .over, far: false, layers: [
                    ArtLayer("M1 -12 L3 -12 Q5 -12 5 -10 L5 10 Q5 12 3 12 L1 12 Q-1 12 -1 10 L-1 -10 Q-1 -12 1 -12 Z", .solid("#2E6BFF", 1), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M2 4.4 C4 4.4 5.6 6 5.6 8 C5.6 10 4 11.6 2 11.6 C0 11.6 -1.6 10 -1.6 8 C-1.6 6 0 4.4 2 4.4 Z", .linear(["#FFF1B8", "#E0A21B"]), stroke: "#0A0D12", width: 1.4)
                ])
            ]
        case "dawn.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M6 -2 Q-24 -24 -92 -38 Q-104 -34 -108 -20 Q-104 -8 -90 -4 Q-40 -6 2 8 Z", .linear(["#5A8CFF", "#2E6BFF", "#1A3F99"]), stroke: "#0A0D12", width: 2.6),
                    ArtLayer("M-92 -38 Q-104 -34 -108 -20 Q-104 -8 -90 -4", .solid("#000000", 0), stroke: "#E0A21B", width: 3),
                    ArtLayer("M-14 -18 Q-50 -28 -84 -30", .solid("#000000", 0), stroke: "#000000", width: 3),
                    ArtLayer("M4 6.5 L2.6 2.9 L-1.2 2.7 L1.7 0.3 L0.8 -3.4 L4 -1.4 L7.2 -3.4 L6.3 0.3 L9.2 2.7 L5.4 2.9 Z", .linear(["#FFF1B8", "#E0A21B"]), stroke: "#0A0D12", width: 1.6)
                ])
            ]
        case "rune.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#6B5A3A", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-15.5 -8 L-9.5 -8 Q-7.5 -8 -7.5 -6 L-7.5 6 Q-7.5 8 -9.5 8 L-15.5 8 Q-17.5 8 -17.5 6 L-17.5 -6 Q-17.5 -8 -15.5 -8 Z", .linear(["#5A5E6A", "#2C2F3A"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-12.5 -5 L-12.5 5 L-12.5 -1 L-15 -4", .solid("#000000", 0), stroke: "#3DF5A0", width: 3.7, blur: 2.5),
                    ArtLayer("M-12.5 -5 L-12.5 5 L-12.5 -1 L-15 -4", .solid("#000000", 0), stroke: "#3DF5A0", width: 1.2),
                    ArtLayer("M-12.5 -5 L-12.5 5 L-12.5 -1 L-15 -4", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M9.5 -8 L15.5 -8 Q17.5 -8 17.5 -6 L17.5 6 Q17.5 8 15.5 8 L9.5 8 Q7.5 8 7.5 6 L7.5 -6 Q7.5 -8 9.5 -8 Z", .linear(["#5A5E6A", "#2C2F3A"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M12.5 -5 L12.5 5 L12.5 -1 L15 -4", .solid("#000000", 0), stroke: "#3DF5A0", width: 3.7, blur: 2.5),
                    ArtLayer("M12.5 -5 L12.5 5 L12.5 -1 L15 -4", .solid("#000000", 0), stroke: "#3DF5A0", width: 1.2),
                    ArtLayer("M12.5 -5 L12.5 5 L12.5 -1 L15 -4", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "rune.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M14 2 L27 4 L20 -2 Z", .linear(["#FFFFFF", "#C9A86A"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-7 -3 Q-9 14 -6 16 L7 16 Q7 8 10 6 Q20 4 21 -1 L21 -3 Z", .linear(["#E6D2A2", "#C9A86A", "#6B5A3A"]), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-7 -3 L22 -3 Q24.5 -4.5 22 -6 L-6 -6 Q-8.5 -5.5 -7 -3 Z", .solid("#3A2E1E", 1), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M-6 6 L6 6 Q7 6 7 7 L7 8 Q7 9 6 9 L-6 9 Q-7 9 -7 8 L-7 7 Q-7 6 -6 6 Z", .solid("#6B5A3A", 1), stroke: "#0A0D12", width: 1.2),
                    ArtLayer("M0 13 L0 10", .solid("#000000", 0), stroke: "#3DF5A0", width: 3.5, blur: 2.5),
                    ArtLayer("M0 13 L0 10", .solid("#000000", 0), stroke: "#3DF5A0", width: 1),
                    ArtLayer("M0 13 L0 10", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "rune.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-8 -7.5 L-2 -7.5 Q0 -7.5 0 -5.5 L0 5.5 Q0 7.5 -2 7.5 L-8 7.5 Q-10 7.5 -10 5.5 L-10 -5.5 Q-10 -7.5 -8 -7.5 Z", .solid("#6B5A3A", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-3 -5 L-1 -13 L1 -5 Z", .linear(["#FFFFFF", "#C9A86A"]), stroke: "#0A0D12", width: 1.3),
                    ArtLayer("M1 -5.5 L3 -13.5 L5 -5.5 Z", .linear(["#FFFFFF", "#C9A86A"]), stroke: "#0A0D12", width: 1.3),
                    ArtLayer("M5 -4 L7 -12 L9 -4 Z", .linear(["#FFFFFF", "#C9A86A"]), stroke: "#0A0D12", width: 1.3),
                    ArtLayer("M1.5 -6.5 C5.4 -6.5 8.5 -3.6 8.5 0 C8.5 3.6 5.4 6.5 1.5 6.5 C-2.4 6.5 -5.5 3.6 -5.5 0 C-5.5 -3.6 -2.4 -6.5 1.5 -6.5 Z", .solid("#C9A86A", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M4 3 L6.5 1", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4 -1.5 L6.5 -3", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M-6 -4 L-6 4 L-6 0 L-3 -3", .solid("#000000", 0), stroke: "#3DF5A0", width: 3.5, blur: 2.5),
                    ArtLayer("M-6 -4 L-6 4 L-6 0 L-3 -3", .solid("#000000", 0), stroke: "#3DF5A0", width: 1),
                    ArtLayer("M-6 -4 L-6 4 L-6 0 L-3 -3", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "rune.top":
            return [
                GearPart(anchor: .torso, z: .over, far: false, layers: [
                    ArtLayer("M40 -16 Q52 -20 56 -8 Q58 4 52 14 Q46 18 40 15 Q44 0 40 -16 Z", .linear(["#A07850", "#5A3F26"]), stroke: "#0A0D12", width: 2),
                    ArtLayer("M46 -10 L49 -4", .solid("#000000", 0), stroke: "#3A2814", width: 1.2),
                    ArtLayer("M47 4 L50 9", .solid("#000000", 0), stroke: "#3A2814", width: 1.2)
                ]),
                GearPart(anchor: .torso, z: .limb, far: false, layers: [
                    ArtLayer("M1.5 -11 L4.5 -11 Q6 -11 6 -9.5 L6 9.5 Q6 11 4.5 11 L1.5 11 Q0 11 0 9.5 L0 -9.5 Q0 -11 1.5 -11 Z", .solid("#5A4A30", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M1 3 L5 3 Q6.5 3 6.5 4.5 L6.5 8.5 Q6.5 10 5 10 L1 10 Q-0.5 10 -0.5 8.5 L-0.5 4.5 Q-0.5 3 1 3 Z", .solid("#C9A86A", 1), stroke: "#0A0D12", width: 1.2),
                    ArtLayer("M1.5 5 L5 8", .solid("#000000", 0), stroke: "#3DF5A0", width: 3.3, blur: 2.5),
                    ArtLayer("M1.5 5 L5 8", .solid("#000000", 0), stroke: "#3DF5A0", width: 0.8),
                    ArtLayer("M1.5 5 L5 8", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ])
            ]
        case "rune.bottom":
            return [
                GearPart(anchor: .torso, z: .over, far: false, layers: [
                    ArtLayer("M4 -12 L4 -3 L-18 -2 L-18 -13 Z", .linear(["#C9A86A", "#6B5A3A"]), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M4 -4 L4 5 L-18 6 L-18 -5 Z", .linear(["#C9A86A", "#6B5A3A"]), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M4 4 L4 13 L-18 14 L-18 3 Z", .linear(["#C9A86A", "#6B5A3A"]), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M-6 2 L-12 2", .solid("#000000", 0), stroke: "#3DF5A0", width: 3.4, blur: 2.5),
                    ArtLayer("M-6 2 L-12 2", .solid("#000000", 0), stroke: "#3DF5A0", width: 0.9),
                    ArtLayer("M-6 2 L-12 2", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8)
                ]),
                GearPart(anchor: .shin, z: .limb, far: true, layers: [
                    ArtLayer("M-3 3 L2 15 L6 3 Z", .linear(["#FFFFFF", "#C9A86A"]), stroke: "#0A0D12", width: 1.5)
                ])
            ]
        case "rune.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M-70 -16 L10 -26 L18 -21 L10 -16 L-70 -8 Z", .linear(["#FFFFFF", "#9AA4AF"]), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-62 -12 L4 -21", .solid("#000000", 0), stroke: "#3DF5A0", width: 3.5, blur: 2.5),
                    ArtLayer("M-62 -12 L4 -21", .solid("#000000", 0), stroke: "#3DF5A0", width: 1),
                    ArtLayer("M-62 -12 L4 -21", .solid("#000000", 0), stroke: "#FFFFFF", width: 0.8),
                    ArtLayer("M11.5 -34 L13.5 -34 Q15 -34 15 -32.5 L15 -9.5 Q15 -8 13.5 -8 L11.5 -8 Q10 -8 10 -9.5 L10 -32.5 Q10 -34 11.5 -34 Z", .linear(["#E6D2A2", "#C9A86A"]), stroke: "#0A0D12", width: 1.8),
                    ArtLayer("M17 -24 L25 -24 Q27 -24 27 -22 L27 -21 Q27 -19 25 -19 L17 -19 Q15 -19 15 -21 L15 -22 Q15 -24 17 -24 Z", .solid("#5A3B22", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M29 -24.9 C30.9 -24.9 32.4 -23.4 32.4 -21.5 C32.4 -19.6 30.9 -18.1 29 -18.1 C27.1 -18.1 25.6 -19.6 25.6 -21.5 C25.6 -23.4 27.1 -24.9 29 -24.9 Z", .solid("#3DF5A0", 1), stroke: "#0A0D12", width: 1.4)
                ])
            ]
        case "astral.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.6 L7.8 -1.6 Q9 -1.6 9 -0.4 L9 0.4 Q9 1.6 7.8 1.6 L-7.8 1.6 Q-9 1.6 -9 0.4 L-9 -0.4 Q-9 -1.6 -7.8 -1.6 Z", .solid("#8FE3FF", 1), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M-12.5 9 L-14.9 3.2 L-21.1 2.8 L-16.3 -1.2 L-17.8 -7.3 L-12.5 -4 L-7.2 -7.3 L-8.7 -1.2 L-3.9 2.8 L-10.1 3.2 Z", .solid("#FF6BD6", 0.8), blur: 2.5),
                    ArtLayer("M-12.5 8.5 L-14.7 3.1 L-20.6 2.6 L-16.1 -1.2 L-17.5 -6.9 L-12.5 -3.8 L-7.5 -6.9 L-8.9 -1.2 L-4.4 2.6 L-10.3 3.1 Z", .linear(["#FFFFFF", "#8FE3FF"]), stroke: "#0A0D12", width: 1.6),
                    ArtLayer("M12.5 9 L10.1 3.2 L3.9 2.8 L8.7 -1.2 L7.2 -7.3 L12.5 -4 L17.8 -7.3 L16.3 -1.2 L21.1 2.8 L14.9 3.2 Z", .solid("#FF6BD6", 0.8), blur: 2.5),
                    ArtLayer("M12.5 8.5 L10.3 3.1 L4.4 2.6 L8.9 -1.2 L7.5 -6.9 L12.5 -3.8 L17.5 -6.9 L16.1 -1.2 L20.6 2.6 L14.7 3.1 Z", .linear(["#FFFFFF", "#FF6BD6"]), stroke: "#0A0D12", width: 1.6)
                ])
            ]
        case "astral.feet":
            return [
                GearPart(anchor: .foot, z: .limb, far: true, layers: [
                    ArtLayer("M-6 -3 Q-8 8 -3 10 L4 10 Q10 6 16 4 Q24 2 27 8 Q30 4 26 0 Q22 -3 18 -3 Z", .linear(["#8FE3FF", "#5A45B0"]), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M27.5 6 C28.6 6 29.5 6.9 29.5 8 C29.5 9.1 28.6 10 27.5 10 C26.4 10 25.5 9.1 25.5 8 C25.5 6.9 26.4 6 27.5 6 Z", .solid("#FF6BD6", 1), stroke: "#0A0D12", width: 1.2),
                    ArtLayer("M5 8 L4.3 5.7 L2 5 L4.3 4.3 L5 2 L5.7 4.3 L8 5 L5.7 5.7 Z", .solid("#FFFFFF", 1))
                ])
            ]
        case "astral.hands":
            return [
                GearPart(anchor: .fist, z: .limb, far: true, layers: [
                    ArtLayer("M-8 -7 L-2 -7 Q0 -7 0 -5 L0 5 Q0 7 -2 7 L-8 7 Q-10 7 -10 5 L-10 -5 Q-10 -7 -8 -7 Z", .solid("#22184A", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M1.5 -5.7 C4.9 -5.7 7.7 -3.1 7.7 0 C7.7 3.1 4.9 5.7 1.5 5.7 C-1.9 5.7 -4.7 3.1 -4.7 0 C-4.7 -3.1 -1.9 -5.7 1.5 -5.7 Z", .solid("#22184A", 1), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M4 3 L6.5 1", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M4 -1.5 L6.5 -3", .solid("#000000", 0), stroke: "#0A0D12", width: 1.1),
                    ArtLayer("M13 2 C16.3 2 19 4.7 19 8 C19 11.3 16.3 14 13 14 C9.7 14 7 11.3 7 8 C7 4.7 9.7 2 13 2 Z", .solid("#FF6BD6", 0.85), blur: 3),
                    ArtLayer("M13 3.4 C15.5 3.4 17.6 5.5 17.6 8 C17.6 10.5 15.5 12.6 13 12.6 C10.5 12.6 8.4 10.5 8.4 8 C8.4 5.5 10.5 3.4 13 3.4 Z", .linear(["#FFFFFF", "#8FE3FF"]), stroke: "#0A0D12", width: 1.4),
                    ArtLayer("M13 6 C17.4 6 21 6.9 21 8 C21 9.1 17.4 10 13 10 C8.6 10 5 9.1 5 8 C5 6.9 8.6 6 13 6 Z", .solid("#000000", 0), stroke: "#FF6BD6", width: 1.2)
                ])
            ]
        case "astral.top":
            return [
                GearPart(anchor: .torso, z: .over, far: false, layers: [
                    ArtLayer("M6 -12 L-34 -20 Q-36 -2 -34 16 L6 13 Z", .linear(["#22184A", "#3A2A70"]), stroke: "#0A0D12", width: 2.2),
                    ArtLayer("M-33 -18 L-33 15", .solid("#000000", 0), stroke: "#FF6BD6", width: 2),
                    ArtLayer("M-16 3.5 L-16.8 1.1 L-19.3 1.1 L-17.3 -0.4 L-18.1 -2.8 L-16 -1.4 L-13.9 -2.8 L-14.7 -0.4 L-12.7 1.1 L-15.2 1.1 Z", .solid("#8FE3FF", 1)),
                    ArtLayer("M-26 11.5 L-26.6 9.6 L-28.5 9 L-26.6 8.4 L-26 6.5 L-25.4 8.4 L-23.5 9 L-25.4 9.6 Z", .solid("#FF6BD6", 1)),
                    ArtLayer("M-24 -7.8 L-24.6 -9.4 L-26.2 -10 L-24.6 -10.6 L-24 -12.2 L-23.4 -10.6 L-21.8 -10 L-23.4 -9.4 Z", .solid("#8FE3FF", 1)),
                    ArtLayer("M44 -13 Q54 -18 58 -12 L54 -2 Z", .solid("#FF6BD6", 1), stroke: "#0A0D12", width: 1.8)
                ])
            ]
        case "astral.bottom":
            return [
                GearPart(anchor: .shin, z: .limb, far: true, layers: [
                    ArtLayer("M14 5 L13.3 2.7 L11 2 L13.3 1.3 L14 -1 L14.7 1.3 L17 2 L14.7 2.7 Z", .solid("#8FE3FF", 1)),
                    ArtLayer("M24 -0.6 L23.4 -2.4 L21.6 -3 L23.4 -3.6 L24 -5.4 L24.6 -3.6 L26.4 -3 L24.6 -2.4 Z", .solid("#FF6BD6", 1)),
                    ArtLayer("M30 -8 L37 -12 L36 -4 L38 0 L36 4 L37 12 L30 8 Z", .solid("#22184A", 1), stroke: "#FF6BD6", width: 1.4)
                ])
            ]
        case "astral.back":
            return [
                GearPart(anchor: .nape, z: .back, far: false, layers: [
                    ArtLayer("M2 -6 Q30 -30 42 -60 Q16 -52 12 -44 Q20 -64 18 -76 Q-2 -58 0 -46 Q-6 -66 -24 -70 Q-14 -50 -10 -36 Q-20 -48 -42 -50 Q-24 -30 -14 -16 Z", .solid("#FF6BD6", 0.5), stroke: "#FF6BD6", width: 1.4, blur: 3),
                    ArtLayer("M2 -6 Q30 -30 42 -60 Q16 -52 12 -44 Q20 -64 18 -76 Q-2 -58 0 -46 Q-6 -66 -24 -70 Q-14 -50 -10 -36 Q-20 -48 -42 -50 Q-24 -30 -14 -16 Z", .linear(["#8FE3FF", "#FF6BD6"]), stroke: "#FF6BD6", width: 1.4),
                    ArtLayer("M2 -6 Q30 -30 34 -60 Q16 -52 12 -44 Q20 -64 10 -76 Q-2 -58 0 -46 Q-6 -66 -16 -70 Q-14 -50 -10 -36 Q-20 -48 -34 -50 Q-24 -30 -14 -16 Z", .linear(["#FFFFFF", "#FF6BD6", "#8FE3FF"]), stroke: "#FF6BD6", width: 1.4)
                ])
            ]
        case "default.bell":
            return [
                GearPart(anchor: .grip, z: .grip, far: true, layers: [
                    ArtLayer("M-7.8 -1.5 L7.8 -1.5 Q9 -1.5 9 -0.3 L9 0.3 Q9 1.5 7.8 1.5 L-7.8 1.5 Q-9 1.5 -9 0.3 L-9 -0.3 Q-9 -1.5 -7.8 -1.5 Z", .solid("#8D98A4", 1), stroke: "#0A0D12", width: 1.5),
                    ArtLayer("M9.5 -6.5 L11.5 -6.5 Q13.5 -6.5 13.5 -4.5 L13.5 4.5 Q13.5 6.5 11.5 6.5 L9.5 6.5 Q7.5 6.5 7.5 4.5 L7.5 -4.5 Q7.5 -6.5 9.5 -6.5 Z", .solid("#3E4652", 1), stroke: "#0A0D12", width: 2),
                    ArtLayer("M-11.5 -6.5 L-9.5 -6.5 Q-7.5 -6.5 -7.5 -4.5 L-7.5 4.5 Q-7.5 6.5 -9.5 6.5 L-11.5 6.5 Q-13.5 6.5 -13.5 4.5 L-13.5 -4.5 Q-13.5 -6.5 -11.5 -6.5 Z", .solid("#3E4652", 1), stroke: "#0A0D12", width: 2)
                ])
            ]
        default:
            return []
        }
    }
}
