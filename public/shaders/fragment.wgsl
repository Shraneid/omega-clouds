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

struct Sphere {
    position: vec3<f32>,
    radius: f32,
    density: f32
}

const NUMBER_OF_SPHERES = 5;
var<private> spheres: array<Sphere, NUMBER_OF_SPHERES>;

@fragment
fn fs(in: VertexOut) -> @location(0) vec4f {
    spheres[0] = Sphere(vec3f(-0.1f, 0.05f, 0.0f), 0.35f, 1.0f);
    spheres[1] = Sphere(vec3f(0.0f, -0.2f, 0.1f), 0.3f, 1.0f);
    spheres[2] = Sphere(vec3f(0.15f, -0.1f, 0.1f), 0.25f, 1.0f);
    spheres[3] = Sphere(vec3f(-0.3f, -0.2f, -0.1f), 0.2f, 1.0f);
    spheres[4] = Sphere(vec3f(-0.1f, -0.2f, -0.2f), 0.3f, 1.0f);

    const NUM_STEPS = 100.0f;
    const FALLOFF_RATE = 10.0f;

    var stepSize = 1.41f / NUM_STEPS;

    let camera = uniforms.cameraPosition.xyz;

    // ray marching the cloud
    let rayDirection = normalize(in.worldPos - camera);

    var currentPosition = in.worldPos;
    var density = 0.0f;
    for (var i = 0; i < i32(NUM_STEPS); i++){
        currentPosition = currentPosition + rayDirection * stepSize;
        for (var i = 0; i < NUMBER_OF_SPHERES; i++){
            let sphere = spheres[i];
            let distanceToCenter = length(sphere.position - currentPosition);
            let isInsideRadius = step(distanceToCenter, sphere.radius);
            let interpolatedDistance = ((sphere.radius - distanceToCenter) / sphere.radius);
            let test = exp(-distanceToCenter * distanceToCenter * FALLOFF_RATE);
            density += isInsideRadius * test * sphere.density / NUM_STEPS * 3.0f;
        }
    }

    return vec4(1.0, 1.0, 1.0, density);
}
