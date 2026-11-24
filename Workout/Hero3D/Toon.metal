// 3D 角色的卡通著色（RealityKit CustomMaterial，unlit 自己算光）。
// 對照 Blender 原型 hero_proto.py 的 toon()：兩階明暗＋亮面＋邊緣光，金屬多一塊硬邊高光。
// 參數：base_color_tint＝亮面色；custom_parameter＝(塗色 rgb, 暗面倍率)；roughness＝塗色的暗面倍率；metallic > 0.5＝有高光。
// 塗在身體上的衣服（背心）：uv0.x > 0 的地方換成塗色。
#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

constant float3 kLight = float3(-0.45, 0.75, 0.55);   // 世界座標：左上前方
constant float3 kRim = float3(0.55, 0.75, 1.0);

static half3 toonColor(realitykit::surface_parameters params)
{
    auto mc = params.material_constants();
    float4 cp = params.uniforms().custom_parameter();
    float3 base = float3(mc.base_color_tint());
    float shade = cp.w;
    float2 uv = params.geometry().uv0();
    if (uv.x > 0.0 && (cp.x + cp.y + cp.z) > 0.0) {
        base = cp.xyz;
        shade = float(mc.roughness_scale());
    }
    float3 n = normalize(params.geometry().normal());
    float3 v = normalize(params.geometry().view_direction());
    float3 l = normalize(kLight);
    float ndl = dot(n, l);
    float3 c = ndl < 0.0 ? base * shade : (ndl > 0.8 ? min(base * 1.18 + 0.06, float3(1.0)) : base);
    float facing = 1.0 - saturate(abs(dot(n, v)));
    if (facing > 0.72) c += kRim * 0.3;
    if (float(mc.metallic_scale()) > 0.5) {
        float3 h = normalize(l + v);
        if (pow(saturate(dot(n, h)), 40.0) > 0.5) c += 0.55;
    }
    return half3(saturate(c));
}

// unlit 模式只吃 emissive（寫 base color 會全黑，0.36.3 在手機上驗證過）
[[visible]]
void toonSurface(realitykit::surface_parameters params)
{
    params.surface().set_base_color(half3(0));
    params.surface().set_emissive_color(toonColor(params));
}

// 發光、眼睛、描邊：純色
[[visible]]
void flatSurface(realitykit::surface_parameters params)
{
    params.surface().set_base_color(half3(0));
    params.surface().set_emissive_color(half3(params.material_constants().base_color_tint()));
}
