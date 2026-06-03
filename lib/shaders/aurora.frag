#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform vec3 uColor1;  // primary accent
uniform vec3 uColor2;  // secondary accent
uniform vec3 uColor3;  // background base

out vec4 fragColor;

// Simplex-like noise for flowing aurora bands
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec2 st = uv;

    // Time-driven horizontal wave distortion
    float wave = sin(st.y * 6.0 + uTime * 0.3) * 0.04 +
                 sin(st.y * 10.0 - uTime * 0.5) * 0.03;

    // Multiple aurora bands
    float band1 = fbm(vec2(st.x + wave, st.y * 3.0 + uTime * 0.1)) * 0.15;
    float band2 = fbm(vec2(st.x + wave + 0.5, st.y * 2.5 - uTime * 0.13)) * 0.12;
    float band3 = fbm(vec2(st.x + wave - 0.3, st.y * 3.5 + uTime * 0.08)) * 0.10;

    // Combine bands into vertical strips
    float aurora = smoothstep(0.1, 0.5, band1) * (1.0 - abs(st.y - 0.3)) +
                   smoothstep(0.08, 0.4, band2) * (1.0 - abs(st.y - 0.5)) +
                   smoothstep(0.06, 0.35, band3) * (1.0 - abs(st.y - 0.7));

    aurora = clamp(aurora, 0.0, 0.7);

    // Background gradient
    vec3 bg = mix(uColor3, uColor1 * 0.3, st.y);

    // Apply aurora color
    vec3 auroraColor = mix(uColor1, uColor2, sin(st.y * 3.0 + uTime * 0.2) * 0.5 + 0.5);
    vec3 color = bg + aurora * auroraColor * 0.8;

    // Subtle vignette
    float vignette = 1.0 - smoothstep(0.4, 1.4, length(st - 0.5) * 1.5);
    color *= mix(0.7, 1.0, vignette);

    fragColor = vec4(color, 1.0);
}
