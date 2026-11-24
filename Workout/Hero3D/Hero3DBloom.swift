import Metal
import MetalPerformanceShaders
import RealityKit

/// 3D 角色的泛光後處理（Bloom.metal）。在 RealityKit 的繪圖執行緒上跑，所以不屬於 MainActor；
/// strength／threshold 由畫面直接改，讀到舊值只差一格，不加鎖。
final class Hero3DBloom: @unchecked Sendable {
    var strength: Float = 1.2
    var threshold: Float = 0.95
    /// 來源／目標貼圖格式（第一次執行時記下，給診斷看）
    private(set) var formatNote = ""

    private var extract: MTLComputePipelineState?
    private var composite: MTLComputePipelineState?
    private var blur: MPSImageGaussianBlur?
    private var small: MTLTexture?
    private var blurred: MTLTexture?

    func prepare(_ device: MTLDevice) {
        guard let lib = device.makeDefaultLibrary() else { return }
        extract = lib.makeFunction(name: "bloomExtract").flatMap { try? device.makeComputePipelineState(function: $0) }
        composite = lib.makeFunction(name: "bloomComposite").flatMap { try? device.makeComputePipelineState(function: $0) }
        let b = MPSImageGaussianBlur(device: device, sigma: 5)
        b.edgeMode = .clamp
        blur = b
    }

    func run(_ ctx: ARView.PostProcessContext) {
        let src = ctx.sourceColorTexture, dst = ctx.targetColorTexture
        if formatNote.isEmpty {
            formatNote = "來源 \(Self.name(src.pixelFormat)) → 目標 \(Self.name(dst.pixelFormat))，\(src.width)×\(src.height)"
        }
        let w = max(src.width / 4, 1), h = max(src.height / 4, 1)
        if small?.width != w || small?.height != h {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: w, height: h, mipmapped: false)
            d.usage = [.shaderRead, .shaderWrite]
            d.storageMode = .private
            small = ctx.device.makeTexture(descriptor: d)
            blurred = ctx.device.makeTexture(descriptor: d)
        }
        guard let extract, let composite, let blur, let small, let blurred,
              let e1 = ctx.commandBuffer.makeComputeCommandEncoder() else {
            copy(ctx); return
        }
        var t = threshold
        e1.setComputePipelineState(extract)
        e1.setTexture(src, index: 0)
        e1.setTexture(small, index: 1)
        e1.setBytes(&t, length: 4, index: 0)
        e1.dispatchThreads(MTLSize(width: w, height: h, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        e1.endEncoding()

        blur.encode(commandBuffer: ctx.commandBuffer, sourceTexture: small, destinationTexture: blurred)

        guard let e2 = ctx.commandBuffer.makeComputeCommandEncoder() else { return }
        var s = strength
        e2.setComputePipelineState(composite)
        e2.setTexture(src, index: 0)
        e2.setTexture(blurred, index: 1)
        e2.setTexture(dst, index: 2)
        e2.setBytes(&s, length: 4, index: 0)
        e2.dispatchThreads(MTLSize(width: dst.width, height: dst.height, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        e2.endEncoding()
    }

    private func copy(_ ctx: ARView.PostProcessContext) {
        guard let b = ctx.commandBuffer.makeBlitCommandEncoder() else { return }
        b.copy(from: ctx.sourceColorTexture, to: ctx.targetColorTexture)
        b.endEncoding()
    }

    private static func name(_ f: MTLPixelFormat) -> String {
        switch f {
        case .bgra8Unorm: return "bgra8"
        case .bgra8Unorm_srgb: return "bgra8_srgb"
        case .rgba8Unorm: return "rgba8"
        case .rgba8Unorm_srgb: return "rgba8_srgb"
        case .rgba16Float: return "rgba16F"
        case .bgr10_xr, .bgr10_xr_srgb, .bgra10_xr, .bgra10_xr_srgb: return "10bit_xr(\(f.rawValue))"
        default: return "格式 \(f.rawValue)"
        }
    }
}
