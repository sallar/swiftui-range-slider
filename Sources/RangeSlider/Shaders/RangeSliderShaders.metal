#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>

using namespace metal;

static float capsuleDistance(float2 point, float2 halfSize) {
    const float radius = halfSize.y;
    const float2 q = float2(abs(point.x) - (halfSize.x - radius), abs(point.y));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

static half4 sourceOver(half4 foreground, half4 background) {
    return foreground + background * (1.0h - foreground.a);
}

[[ stitchable ]] half4 rangeSliderThumbLens(
    float2 position,
    SwiftUI::Layer layer,
    float2 center,
    float2 size,
    float tintSide,
    float progress
) {
    const half4 source = layer.sample(position);
    const float2 halfSize = size * 0.5;
    const float2 local = position - center;
    const float distance = capsuleDistance(local, halfSize);
    const float coverage = smoothstep(0.8, -0.8, distance);

    const float2 shadowCenter = center + float2(0.0, 3.0);
    const float shadowDistance = capsuleDistance(position - shadowCenter, halfSize);
    const float shadowCoverage =
        (1.0 - smoothstep(-0.5, 7.5, shadowDistance)) *
        (1.0 - coverage) *
        progress;
    half4 result = sourceOver(
        half4(0.0h, 0.0h, 0.0h, half(0.038 * shadowCoverage)),
        source
    );

    if (coverage <= 0.0 || progress <= 0.0) {
        return result;
    }

    const float2 normalized = local / max(halfSize, float2(1.0));
    const float lensMix = coverage * progress;
    const float opticalDepth =
        clamp(1.0 - length(normalized * float2(0.72, 1.0)), 0.0, 1.0);
    const float2 samplePosition =
        center +
        local * float2(
            1.0 - opticalDepth * 0.06,
            1.0 - opticalDepth * 0.10
        ) +
        float2(tintSide * opticalDepth * 2.6, 0.0);

    // Keep the track almost straight, like the pressed system Slider. The
    // small inward sample offset only gives it the subtle magnification and
    // color pull visible through the clear capsule.
    half4 refracted =
        layer.sample(samplePosition) * 0.60h +
        layer.sample(samplePosition + float2(-0.65, 0.0)) * 0.20h +
        layer.sample(samplePosition + float2(0.65, 0.0)) * 0.20h;
    half4 lens = mix(source, refracted, half(lensMix));

    // A low-alpha body keeps the sheet visible while remaining independent
    // from the presentation's material-compositing context.
    const float bodyLight =
        0.105 +
        0.030 * (1.0 - normalized.y) +
        0.012 * (1.0 + normalized.x);
    lens = sourceOver(
        half4(
            half3(half(bodyLight * lensMix)),
            half(bodyLight * lensMix)
        ),
        lens
    );

    const float topWash =
        (1.0 - smoothstep(-0.90, 0.30, normalized.y)) *
        coverage *
        progress *
        0.050;
    lens = sourceOver(
        half4(0.0h, 0.0h, 0.0h, half(topWash)),
        lens
    );

    const float rim = exp(-pow(abs(distance) / 0.82, 2.0)) * progress;
    const float whiteRim =
        rim *
        clamp(0.26 + normalized.x * 0.07 + normalized.y * 0.08, 0.16, 0.40);
    lens = sourceOver(
        half4(
            half3(half(whiteRim)),
            half(whiteRim)
        ),
        lens
    );

    const float neutralRim =
        rim *
        (0.025 + 0.220 * pow(abs(normalized.y), 2.0)) *
        (1.0 - 0.65 * smoothstep(0.0, 0.90, normalized.y));
    lens = sourceOver(
        half4(0.0h, 0.0h, 0.0h, half(neutralRim)),
        lens
    );

    const float topShade =
        rim *
        (1.0 - smoothstep(-0.78, 0.20, normalized.y)) *
        0.19;
    lens = sourceOver(
        half4(0.0h, 0.0h, 0.0h, half(topShade)),
        lens
    );

    // Pull a trace of the actual tint into the selected-side rim. This is the
    // narrow blue edge visible on the system bubble, without inventing rays.
    const half4 selectedTrackColor = layer.sample(
        float2(center.x + tintSide * halfSize.x * 0.82, center.y)
    );
    const float selectedSide = normalized.x * tintSide;
    const float tintRim =
        rim *
        smoothstep(0.15, 0.88, selectedSide) *
        0.28;
    lens = sourceOver(
        selectedTrackColor * half(tintRim),
        lens
    );

    const float topTint =
        rim *
        (1.0 - smoothstep(-0.78, 0.12, normalized.y)) *
        0.22;
    lens = sourceOver(
        selectedTrackColor * half(topTint),
        lens
    );

    const float bottomTint =
        rim *
        smoothstep(0.05, 0.86, normalized.y) *
        0.22;
    lens = sourceOver(
        selectedTrackColor * half(bottomTint),
        lens
    );

    // A restrained inner edge gives the capsule volume on both light and dark
    // content without turning the body into an opaque gray pill.
    const float innerEdge =
        exp(-pow(max(-distance, 0.0) / 2.9, 2.0)) *
        coverage *
        progress;
    const float bottomRight = clamp(
        0.42 - normalized.x * 0.12 - normalized.y * 0.22,
        0.0,
        1.0
    );
    lens = sourceOver(
        half4(0.0h, 0.0h, 0.0h, half(innerEdge * bottomRight * 0.052)),
        lens
    );

    return mix(result, lens, half(coverage));
}
