struct Uniforms {
    view: mat4x4f,
    projection: mat4x4f,
    cameraPosition: vec4f,
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
    var color = vec4f(0.0, 0.0, 0.0, 0.0);

    let camera = uniforms.cameraPosition.xyz;

    // ray marching the cloud
    let rayDirection = normalize(in.worldPos - camera);

    var step = 0.0f;
    for (var i = 0; i < 10; i++){
        let p = in.worldPos + rayDirection * step;
        if (length(p) < 0.5){
            color += vec4f(0.1, 0.1, 0.1, 0.1);
        }
        step += 0.1;
    }
    if (color.r < 0.01) {discard;}

    return color;
}
