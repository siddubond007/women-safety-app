#include <flutter/runtime_effect.glsl>

// The original artwork is the only color source. The grayscale mask gates
// displacement to dark hair pixels; facial features and clothing are static.
uniform sampler2D uPortrait;
uniform sampler2D uHairMask;
uniform float uTime;
uniform float uWidth;
uniform float uHeight;

out vec4 fragColor;

void main() {
  vec2 viewUv = FlutterFragCoord().xy / vec2(uWidth, uHeight);

  // Match BoxFit.cover for the square portrait in the Home hero viewport.
  float viewportAspect = uWidth / uHeight;
  vec2 uv = viewUv;
  if (viewportAspect < 1.0) {
    uv.x = (viewUv.x - 0.5) * viewportAspect + 0.5;
  } else {
    uv.y = (viewUv.y - 0.5) / viewportAspect + 0.5;
  }
  uv = clamp(uv, vec2(0.001), vec2(0.999));

  vec4 portrait = texture(uPortrait, uv);
  float hairMask = texture(uHairMask, uv).r;

  // Slow, layered breeze. The roots barely move; the long lower locks carry
  // the motion. Subtracting the phase-zero value makes the 7.6s loop seamless.
  float rootToTip = smoothstep(0.18, 0.88, uv.y);
  float spatial = uv.y * 10.5 + uv.x * 2.6;
  float phase = uTime * 6.28318530718;
  float broadWave = sin(spatial - phase) - sin(spatial);
  float softWave = sin(spatial * 0.72 - phase + 0.8)
      - sin(spatial * 0.72 + 0.8);
  float fineWave = sin(spatial * 1.45 - phase * 2.0 + 1.4)
      - sin(spatial * 1.45 + 1.4);

  vec2 displacement = rootToTip * vec2(
    0.0080 * broadWave + 0.0028 * softWave + 0.0010 * fineWave,
    0.0005 * (cos(spatial - phase) - cos(spatial))
  );
  vec2 hairUv = clamp(uv + displacement, vec2(0.001), vec2(0.999));
  vec4 flowed = texture(uPortrait, hairUv);
  float sampledHairMask = texture(uHairMask, hairUv).r;

  // Fade displacement at the silhouette edge. This prevents sampling the
  // background through the hair boundary while preserving the exact portrait.
  float interior = smoothstep(0.35, 0.88, sampledHairMask);
  float flowAmount = clamp(hairMask * interior, 0.0, 1.0);
  fragColor = vec4(mix(portrait.rgb, flowed.rgb, flowAmount), portrait.a);
}
