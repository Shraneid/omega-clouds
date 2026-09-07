struct Uniforms {
    view: mat4x4f,
    projection: mat4x4f,
    cameraPosition: vec4f,
    deltaTime: f32,
    elapsedTime: f32
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var texSampler: sampler;
@group(0) @binding(2) var sceneTexture: texture_2d<f32>;

struct VertexOut {
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f,
};

@fragment
fn fs(in: VertexOut) -> @location(0) vec4f {
    var uv = vec2f(in.uv);

    let color = textureSampleLevel(sceneTexture, texSampler, vec2(uv.x, -uv.y), 0.0);
    return color;
//    return vec4(color.rgb, 1.0);
}