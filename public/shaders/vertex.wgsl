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

@vertex
fn main(@location(0) position: vec3f) -> VertexOut {
    var out: VertexOut;

    out.worldPos = position;
    out.pos = uniforms.projection * uniforms.view * vec4f(position, 1.0);

    return out;
}
