struct Uniforms {
    view: mat4x4f,
    projection: mat4x4f,
    cameraPosition: vec4f,
    deltaTime: f32,
    elapsedTime: f32
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var texSampler: sampler;
@group(0) @binding(2) var noiseTexture: texture_2d<f32>;

struct VertexOut {
    @builtin(position) pos: vec4f,
    @location(0) worldPos: vec3f,
};

fn sampleNoise3D(position: vec3f) -> f32 {
    let xy = textureSampleLevel(noiseTexture, texSampler, position.xy + vec2(0.5f), 0.0f).r;
    let yz = textureSampleLevel(noiseTexture, texSampler, position.yz + vec2(0.7f), 0.0f).r;
    let xz = textureSampleLevel(noiseTexture, texSampler, position.xz + vec2(0.9f), 0.0f).r;

    return (xy + yz + xz) / 3.0f;
}

@fragment
fn fs(in: VertexOut) -> @location(0) vec4f {
    const NUM_STEPS = 100.0f;
    const ABSORPTION = 4.0f;

    var stepSize = 1.41f / NUM_STEPS;

    let camera = uniforms.cameraPosition.xyz;

    // ray marching the cloud
    let rayDirection = normalize(in.worldPos - camera);

    var currentPosition = in.worldPos;
    var transmittance = 1.0f;

    for (var i = 0; i < i32(NUM_STEPS); i++){
        currentPosition = currentPosition + rayDirection * stepSize;
        if (
            currentPosition.x > -0.5f && currentPosition.x < 0.5f &&
            currentPosition.y > -0.5f && currentPosition.y < 0.5f &&
            currentPosition.z > -0.5f && currentPosition.z < 0.5f
        ) {
            let density = sampleNoise3D(currentPosition);
            transmittance *= exp(-density * stepSize * ABSORPTION);
        }
    }

    let alpha = 1.0f - transmittance;
    return vec4(1.0, 1.0, 1.0, alpha);
}
