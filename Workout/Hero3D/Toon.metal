// 3D 角色的卡通著色（RealityKit CustomMaterial，unlit 自己算光）。
// 對照 Blender 原型 hero_proto.py 的 toon()：兩階明暗＋亮面＋邊緣光，金屬多一塊硬邊高光。
// 參數：base_color_tint＝亮面色；custom_parameter＝(塗色 rgb, 暗面倍率)；roughness＝塗色的暗面倍率；metallic > 0.5＝有高光。
// 塗在身體上的衣服：0.44.0 起身體改用 outfitSurface（換裝貼圖）；toonSurface 的 uv0.x 塗色留著沒用到。
// 泛光（Bloom.metal）靠亮度挑出發光部位：specular_scale＝一般材質的亮度上限（開泛光時 < 1），
// 發光材質（flat、custom_parameter.w = 1）不設上限、還把最亮的通道拉到 1，只有它們超過門檻。
#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

constant float3 kLight = float3(-0.45, 0.75, 0.55);   // 世界座標：左上前方
constant float3 kRim = float3(0.55, 0.75, 1.0);

// 兩階明暗＋亮面＋邊緣光（＋金屬高光）
static half3 toonLight(realitykit::surface_parameters params, float3 base, float shade, bool spec)
{
    float3 n = normalize(params.geometry().normal());
    float3 v = normalize(params.geometry().view_direction());
    float3 l = normalize(kLight);
    float ndl = dot(n, l);
    float3 c = ndl < 0.0 ? base * shade : (ndl > 0.8 ? min(base * 1.18 + 0.06, float3(1.0)) : base);
    float facing = 1.0 - saturate(abs(dot(n, v)));
    if (facing > 0.72) c += kRim * 0.3;
    if (spec) {
        float3 h = normalize(l + v);
        if (pow(saturate(dot(n, h)), 40.0) > 0.5) c += 0.55;
    }
    return half3(saturate(c));
}

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
    return toonLight(params, base, shade, float(mc.metallic_scale()) > 0.5);
}

// 換裝貼圖（export_app.py 烘的，2N×N）：左半＝亮面色（sRGB 編碼），右半 R＝有沒有蓋住、G＝暗面倍率。
static float3 srgbToLinear(float3 c)
{
    return select(pow((c + 0.055) / 1.055, float3(2.4)), c / 12.92, c <= 0.04045);
}

static bool outfitLayer(texture2d<half> tex, float2 uv, thread float3 &base, thread float &shade)
{
    constexpr sampler smp(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::none);
    half4 m = tex.sample(smp, float2(0.5 + uv.x * 0.5, uv.y));
    if (m.r < 0.5h) return false;
    base = srgbToLinear(float3(tex.sample(smp, float2(uv.x * 0.5, uv.y)).rgb));
    shade = float(m.g);
    return true;
}

// 身體、衣服網格：先看上衣圖（custom 貼圖），沒蓋住再看下身圖（base color 貼圖），都沒有就是皮膚（base_color_tint）。
// 衣服網格兩個欄位放同一張圖。網格不動，換貼圖就換裝。
[[visible]]
void outfitSurface(realitykit::surface_parameters params)
{
    auto mc = params.material_constants();
    float2 uv = params.geometry().uv0();
    uv.y = 1.0 - uv.y;                     // USD 的 v 朝上，Metal 貼圖第 0 列在上
    float3 base = float3(mc.base_color_tint());
    float shade = params.uniforms().custom_parameter().w;
    if (!outfitLayer(params.textures().custom(), uv, base, shade)) {
        outfitLayer(params.textures().base_color(), uv, base, shade);
    }
    half cap = half(mc.specular_scale());
    params.surface().set_base_color(half3(0));
    params.surface().set_emissive_color(min(toonLight(params, base, shade, false), half3(cap)));
}

// unlit 模式只吃 emissive（寫 base color 會全黑，0.36.3 在手機上驗證過）
[[visible]]
void toonSurface(realitykit::surface_parameters params)
{
    half cap = half(params.material_constants().specular_scale());
    params.surface().set_base_color(half3(0));
    params.surface().set_emissive_color(min(toonColor(params), half3(cap)));
}

// 發光、眼睛、描邊：純色
[[visible]]
void flatSurface(realitykit::surface_parameters params)
{
    auto mc = params.material_constants();
    half3 c = half3(mc.base_color_tint());
    half cap = half(mc.specular_scale());
    if (params.uniforms().custom_parameter().w > 0.5 && cap < 0.999h) {
        c = c / max(max(c.r, max(c.g, c.b)), 0.001h);
    } else {
        c = min(c, half3(cap));
    }
    params.surface().set_base_color(half3(0));
    params.surface().set_emissive_color(c);
}

// 著色器描邊：同一份網格再畫一次，沿（平滑過的）法線往外撐 custom_parameter.x 公尺，剔除正面。
// 法線由 App 把同位置的頂點平均過，硬邊零件撐開才不會裂。
[[visible]]
void outlineGeom(realitykit::geometry_parameters params)
{
    float w = params.uniforms().custom_parameter().x;
    float3 n = normalize(params.geometry().normal());
    params.geometry().set_model_position_offset(n * w);
}

// 特效的金幣圓面（Hero3DFX.swift）：亮面色＝base color 貼圖 × tint，明暗和 toonSurface 相同（不加塗色、不加高光）。
// uv 由 App 自己組網格時給（v 朝下，和貼圖列同向），不用翻。
[[visible]]
void toonTexSurface(realitykit::surface_parameters params)
{
    constexpr sampler smp(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::none);
    auto mc = params.material_constants();
    float2 uv = params.geometry().uv0();
    float3 base = float3(mc.base_color_tint()) * float3(params.textures().base_color().sample(smp, uv).rgb);
    half cap = half(mc.specular_scale());
    params.surface().set_base_color(half3(0));
    params.surface().set_emissive_color(min(toonLight(params, base, params.uniforms().custom_parameter().w, false), half3(cap)));
}
