#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// -------------------------------------------------------------
// Tuning Parameters: Crisp Cinematic HDR + Contact Depth (Zero Haze)
// -------------------------------------------------------------
// 1. Crispness & Micro-contrast (Razor sharp edges, zero ghosting)
const float SHARPNESS = 0.32;

// 2. Exposure & Darkness ("Tad dark", rich shadow baseline, no washed-out haze)
const float EXPOSURE = 0.93;
const float GAMMA_CRUSH = 1.05;

// 3. Filmic HDR Tone Curve & Specular Pop
const float CONTRAST = 0.24;
const float SPECULAR_POP = 0.35;    // Highlights & magic glints pop cleanly without fog

// 4. Color Grading & Controlled Vibrance (Tasteful, not oversaturated)
const float VIBRANCE = 0.08;
const vec3 SATURATION_TINT = vec3(1.01, 1.00, 0.99);

// 5. Corner Darkness (Cinematic Vignette)
const float VIGNETTE_STRENGTH = 0.32;

// 6. Subtle Film Grain (Very little grainy texture)
const float GRAIN_INTENSITY = 0.026;

// 7. Ray-Traced Style Contact Depth (Pseudo-AO in crevices and seams)
const float CONTACT_AO = 0.22;

void main() {
    ivec2 texDim = textureSize(tex, 0);
    vec2 px = 1.0 / vec2(texDim);

    // Center pixel
    vec4 centerSample = texture(tex, v_texcoord);
    vec3 color = centerSample.rgb;

    // --- 1. CRISP MICRO-SHARPENING (Adaptive Unsharp Mask) ---
    vec3 up    = texture(tex, v_texcoord + vec2(0.0, -px.y)).rgb;
    vec3 down  = texture(tex, v_texcoord + vec2(0.0,  px.y)).rgb;
    vec3 left  = texture(tex, v_texcoord + vec2(-px.x, 0.0)).rgb;
    vec3 right = texture(tex, v_texcoord + vec2( px.x, 0.0)).rgb;

    vec3 neighborsAvg = (up + down + left + right) * 0.25;
    vec3 diff = color - neighborsAvg;

    // Clamp sharpness to avoid halos/ringing around high-contrast edges
    vec3 sharpColor = color + diff * SHARPNESS;
    vec3 minVal = min(color, min(min(up, down), min(left, right)));
    vec3 maxVal = max(color, max(max(up, down), max(left, right)));
    color = clamp(sharpColor, minVal, maxVal);

    const vec3 lumaWeight = vec3(0.2126, 0.7152, 0.0722);
    float centerLuma = dot(color, lumaWeight);
    float avgLuma = dot(neighborsAvg, lumaWeight);

    // --- 2. RAY-TRACED CONTACT SHADOWS (Pseudo-AO) ---
    // Deepens fine crevices, seams, and contact ambient occlusion
    float aoFactor = clamp((avgLuma - centerLuma) * 2.5, 0.0, 1.0);
    color = color * (1.0 - aoFactor * CONTACT_AO);

    // --- 3. SPECULAR POP (Crisp Highlight Boost - Zero Haze) ---
    // Boosts intense specular glints, visions, and runes locally without any wide blur or ghosting
    float specMask = smoothstep(0.68, 0.98, centerLuma);
    color += color * (specMask * SPECULAR_POP);

    // --- 4. TAD DARK / EXPOSURE & SHADOW DEPTH ---
    color = color * EXPOSURE;
    color = pow(max(color, vec3(0.0)), vec3(GAMMA_CRUSH));

    // --- 5. PSEUDO-HDR / FILMIC S-CURVE CONTRAST ---
    vec3 sCurve = color * color * (3.0 - 2.0 * color);
    color = mix(color, sCurve, CONTRAST);

    // --- 6. CONTROLLED VIBRANCE & NATURAL COLOR POP ---
    float maxC = max(color.r, max(color.g, color.b));
    float minC = min(color.r, min(color.g, color.b));
    float sat = maxC - minC;

    // Vibrance formula: boosts desaturated pixels more, preserves already-saturated ones
    vec3 vibFactor = vec3(1.0 + VIBRANCE * (1.0 - sat));
    color = mix(vec3(dot(color, lumaWeight)), color, vibFactor);

    // Subtle cinematic tint balance
    color = color * SATURATION_TINT;

    // --- 7. CORNER DARKNESS (VIGNETTE) ---
    float aspect = float(texDim.x) / float(texDim.y);
    vec2 vigCoord = (v_texcoord - 0.5) * vec2(aspect, 1.0);
    float vigDist = length(vigCoord);
    float vigFactor = smoothstep(0.45, 1.05, vigDist);
    color = color * (1.0 - vigFactor * VIGNETTE_STRENGTH);

    // --- 8. VERY LITTLE GRAINY TEXTURE (FILM GRAIN) ---
    float noise = fract(sin(dot(v_texcoord * vec2(texDim), vec2(12.9898, 78.233))) * 43758.5453);
    float grainVal = (noise - 0.5) * GRAIN_INTENSITY;
    float grainMask = smoothstep(0.01, 0.15, centerLuma) * (1.0 - smoothstep(0.80, 1.0, centerLuma));
    color += grainVal * grainMask;

    fragColor = vec4(clamp(color, 0.0, 1.0), centerSample.a);
}
