// 3D 角色的泛光（ARView.renderCallbacks.postProcess）：
// 1/4 解析度挑出超過門檻的像素 → MPS 高斯模糊 → 疊回原圖。
// 一般材質開泛光時亮度上限 < 門檻（Toon.metal 的 specular_scale），所以只有發光部位會被挑出來。
#include <metal_stdlib>
using namespace metal;

kernel void bloomExtract(texture2d<half, access::sample> src [[texture(0)]],
                         texture2d<half, access::write> dst [[texture(1)]],
                         constant float &threshold [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    half3 c = src.sample(s, uv).rgb;
    half m = max(c.r, max(c.g, c.b));
    half k = smoothstep(half(threshold), half(threshold) + 0.03h, m);
    dst.write(half4(c * k, 1.0h), gid);
}

kernel void bloomComposite(texture2d<half, access::read> src [[texture(0)]],
                           texture2d<half, access::sample> glow [[texture(1)]],
                           texture2d<half, access::write> dst [[texture(2)]],
                           constant float &strength [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    half4 c = src.read(gid);
    half3 g = glow.sample(s, uv).rgb;
    dst.write(half4(c.rgb + g * half(strength), c.a), gid);
}
