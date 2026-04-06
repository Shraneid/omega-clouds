struct Uniforms {
    view: mat4x4f,
    projection: mat4x4f,
    deltaTime: f32,
    elapsedTime: f32
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;

struct VertexOut {
    @builtin(position) pos: vec4f,
    @location(0) worldPos: vec3f,
};

@fragment
fn fs(in: VertexOut) -> @location(0) vec4f {
    return vec4(1.0, 0.0, 0.0, 1.0);
}
