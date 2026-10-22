//
//  GemKaleidoscope.metal
//  favorium
//
//  The view from inside a gem. Every destination pixel is folded into a single
//  mirrored wedge (like the mirrors in a kaleidoscope tube) and sampled from
//  the living source scene drawn by GemInteriorView.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

/// - size:      the view's size in points
/// - segments:  mirror wedges around the centre (from the gem family's geometry)
/// - rotation:  twist of the tube, in radians
/// - zoom:      how much of the source a wedge spans (smaller = closer)
/// - focus:     the source point the wedges radiate from, in points
/// - facetGlow: strength of the bright cut lines along the mirror seams
[[ stitchable ]] half4 gemKaleidoscope(float2 position, SwiftUI::Layer layer,
                                       float2 size, float segments, float rotation,
                                       float zoom, float2 focus, float facetGlow)
{
    float2 center = size * 0.5;
    float2 p = position - center;
    float r = length(p);

    // Fold the angle into one wedge, then mirror it so neighbouring wedges meet seamlessly
    float wedge = 2.0 * M_PI_F / max(segments, 2.0);
    float a = atan2(p.y, p.x) + rotation;
    a = a - wedge * floor(a / wedge);
    float folded = min(a, wedge - a);

    float2 s = focus + float2(cos(folded), sin(folded)) * r * zoom;

    // Mirror-repeat into the layer so no sample ever falls outside it
    float2 period = size * 2.0;
    float2 m = s - period * floor(s / period);
    s = select(m, period - m, m > size);
    s = clamp(s, float2(1.0), size - 1.0);

    half4 color = layer.sample(s);

    // Light catching the cut: a thin bright line along each seam, fading out at the centre
    float seamDistance = folded * r;
    float seam = (1.0 - smoothstep(0.0, 1.6, seamDistance)) * smoothstep(10.0, 60.0, r) * facetGlow;
    color.rgb = mix(color.rgb, half3(1.0) * color.a, half(seam * 0.35));
    return color;
}
