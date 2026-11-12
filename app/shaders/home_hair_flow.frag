#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uWidth;
uniform float uHeight;
uniform sampler2D uPortrait;
uniform sampler2D uHairMask;

out vec4 fragColor;

void main() {
  vec2 viewUv = FlutterFragCoord().xy / vec2(uWidth, uHeight);
  // Match BoxFit.cover for the square portrait in the slightly portrait-shaped
  // Home hero viewport, avoiding any change to the original character's shape.
  float viewAspect = uWidth / uHeight;
  vec2 uv = viewUv;
  if (viewAspect < 1.0) {
    uv.x = viewUv.x * viewAspect + (1.0 - viewAspect) * 0.5;
  } else {
    uv.y = viewUv.y / viewAspect + (1.0 - 1.0 / viewAspect) * 0.5;
  }
  vec4 still = texture(uPortrait, uv);
  float hair = texture(uHairMask, uv).r;

  // A slow travelling breeze: each lower section lags behind the section above
  // it, so the real painted locks ripple like flowing silk rather than sliding
  // as one rigid sticker. The mask keeps skin, eyes, clothes and background still.
  float phase = uTime * 6.28318530718;
  float longWave = sin(phase - uv.y * 8.5 + uv.x * 2.2);
  float softWave = sin(phase * 0.72 - uv.y * 5.1 - uv.x * 2.8 + 0.8);
  float fineWave = sin(phase * 1.18 - uv.y * 13.0 + uv.x * 4.0 + 1.4);
  vec2 flow = vec2(
    (longWave * 0.010 + softWave * 0.006 + fineWave * 0.0018),
    cos(phase * 0.82 - uv.y * 7.0 + uv.x) * 0.0028
  );
  vec2 movingUv = clamp(uv + flow * hair, vec2(0.001), vec2(0.999));
  vec4 movingHair = texture(uPortrait, movingUv);
  fragColor = mix(still, movingHair, hair);
}
