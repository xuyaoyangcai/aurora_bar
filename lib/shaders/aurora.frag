#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform vec3 uColor1;   // primary accent
uniform vec3 uColor2;   // secondary accent
uniform vec3 uColor3;   // background base
uniform float u_weather_type;      // 0:clear 1:cloud/fog 2:rain 3:snow
uniform float u_weather_intensity; // 0.0 ~ 1.0 ramp

out vec4 fragColor;

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

    // ── Rain: vertical stretch / streak distortion ──
    if (u_weather_type == 2.0) {
        float rx = uv.x * 80.0;
        float ry = uv.y * 35.0;
        float hf  = sin(rx + uTime * 2.5) * cos(ry - uTime * 6.0);
        hf      += sin(rx * 1.7 - uTime * 3.2) * cos(ry * 0.7 + uTime * 5.0);
        hf      += sin(rx * 0.6 + uTime * 0.8) * cos(ry * 1.5 - uTime * 2.0);
        float strength = u_weather_intensity * 0.022;
        st.y += hf * strength;
        st.x += cos(ry * 0.8 + uTime * 1.2) * strength * 0.4;
    }

    // ── Time-driven horizontal wave ──
    float wave = sin(st.y * 6.0 + uTime * 0.3) * 0.04 +
                 sin(st.y * 10.0 - uTime * 0.5) * 0.03;

    // ── Aurora bands (FBM) ──
    float band1 = fbm(vec2(st.x + wave, st.y * 3.0 + uTime * 0.1)) * 0.15;
    float band2 = fbm(vec2(st.x + wave + 0.5, st.y * 2.5 - uTime * 0.13)) * 0.12;
    float band3 = fbm(vec2(st.x + wave - 0.3, st.y * 3.5 + uTime * 0.08)) * 0.10;

    float aurora = smoothstep(0.1, 0.5, band1) * (1.0 - abs(st.y - 0.3)) +
                   smoothstep(0.08, 0.4, band2) * (1.0 - abs(st.y - 0.5)) +
                   smoothstep(0.06, 0.35, band3) * (1.0 - abs(st.y - 0.7));
    aurora = clamp(aurora, 0.0, 0.7);

    // ── Background gradient ──
    vec3 bg = mix(uColor3, uColor1 * 0.3, st.y);

    // ── Aurora color ──
    vec3 auroraColor = mix(uColor1, uColor2, sin(st.y * 3.0 + uTime * 0.2) * 0.5 + 0.5);
    vec3 color = bg + aurora * auroraColor * 0.8;

    // ── Fog / Cloud: desaturation + low-frequency noise mask ──
    if (u_weather_type == 1.0) {
        float lum = dot(color, vec3(0.299, 0.587, 0.114));
        color = mix(color, vec3(lum), 0.45 * u_weather_intensity);
        float fog = noise(st * 3.0 + uTime * 0.05) * 0.25;
        fog      += noise(st * 6.5 - uTime * 0.08) * 0.15;
        color = mix(color, uColor3 * 0.55, fog * u_weather_intensity);
    }

    // ── Snow: slight blue-white lift ──
    if (u_weather_type == 3.0) {
        color = mix(color, color + vec3(0.08, 0.10, 0.14), u_weather_intensity);
        float snowMask = noise(st * 8.0 + uTime * 0.02) * 0.18;
        color = mix(color, vec3(0.85, 0.88, 0.95), snowMask * u_weather_intensity);
    }

    // ── Vignette ──
    float vignette = 1.0 - smoothstep(0.4, 1.4, length(st - 0.5) * 1.5);
    color *= mix(0.7, 1.0, vignette);

    fragColor = vec4(color, 1.0);
}
