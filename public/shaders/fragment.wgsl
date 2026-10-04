const MAX_STEPS: i32 = 40;
const MAX_DISTANCE: f32 = 100.0f;
const EPSILON: f32 = 0.01f;
const MARCH_SIZE: f32 = 0.16f;

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
@group(0) @binding(3) var blueNoiseTexture: texture_2d<f32>;

struct VertexOut {
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f,
};

fn rotateXY(p: vec3f, a: f32) -> vec3f {
    let c = cos(a);
    let s = sin(a);
    return vec3f(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

fn rotateYZ(p: vec3f, a: f32) -> vec3f {
    let c = cos(a);
    let s = sin(a);
    return vec3f(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

fn rotateXZ(p: vec3f, a: f32) -> vec3f {
    let c = cos(a);
    let s = sin(a);
    return vec3f(c * p.x - s * p.z, p.y, s * p.x + c * p.z);
}

fn noise(x: vec3f) -> f32 {
    const offset = vec2(37.0, 239.0);

    let p = floor(x);
    var f = fract(x);
    f = f * f * (3.0 - 2.0 * f);

    let uv = (p.xy + offset * p.z) + f.xy;
    let texSample = textureSampleLevel(noiseTexture, texSampler, (uv + 0.5) / 256.0, 0.0);

    return mix(texSample.g, texSample.r, f.z) * 2.0 - 1.0;
}

fn fbm(p: vec3f) -> f32 {
    var q = p + uniforms.elapsedTime * 0.0003 * vec3(1.0, -0.2, -1.0);

    var f = 0.0f;
    var scale = 0.5f;
    var factor = 2.02f;

    for (var i = 0; i < 6; i++) {
        f += scale * noise(q);
        q *= factor;
        factor += 0.21;
        scale *= 0.5;
    }

    return f;
}

fn sdSphere(a:vec3f, b: vec3f, radius: f32) -> f32 {
    return length(b-a) - radius;
};

fn sdTorus(p: vec3f, t: vec2f) -> f32 {
    let q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

fn sdOctahedron(p: vec3f, s: f32) -> f32 {
    let p1 = abs(p);
    return (p1.x+p1.y+p1.z-s) * 0.57735027;
}

fn sdVerticalCapsule(p: vec3f, h: f32, r: f32) -> f32 {
  let p1 = p - vec3(0.0, clamp(p.y, 0.0, h), 0.0);
  return length( p1 ) - r;
}

fn sdCapsule(p: vec3f, a: vec3f, b: vec3f, r: f32) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}

// animated transitions
//fn scene(p: vec3f) -> f32 {
//    let d1 = sdTorus(p, vec2(1.3, 0.8));
//    let d2 = sdOctahedron(p, 2.0);
//    let d3 = sdVerticalCapsule(p, 2.0, 0.5);
//    let d4 = sdCapsule(p, vec3(0.0, -1., 0.0), vec3(0.0, 1., 0.0), 0.5);
//
//    let f = fbm(p);
//
//    let step1 = min(d1, d4);
//    let step2 = d2;
//    let step3 = d3;
//
//    let elapsedSeconds = uniforms.elapsedTime * 0.001;
//    let numTransitions = 3.0;
//    let stepDuration = 2.0;
//    let cyclePos = (elapsedSeconds % (numTransitions * stepDuration)) / stepDuration;
//
//    let transitionIdx = floor(cyclePos);            // 0 or 1
//    let m = smoothstep(0.6, 1.0, fract(cyclePos));  // 0..1 within this transition
//
//    var start = 0.0;
//    var end = 0.0;
//    if (transitionIdx == 0.0) {
//        start = step1;
//        end   = step2;
//    } else if (transitionIdx == 1.0) {
//        start = step2;
//        end   = step3;
//    } else if (transitionIdx == 2.0) {
//        start = step3;
//        end   = step1;
//    }
//    var distance = mix(start, end, m);
//
//    return - distance + f;
//}

fn scene(p: vec3f) -> f32 {
    let sphere = vec4f(0.0, 0.0, 0.0, 1.0);
    let sphereDistance = sdSphere(p, sphere.xyz, sphere.w);

    let f = fbm(p);

    return - sphereDistance + f;
}

fn rayMarch(rayOrigin: vec3f, rayDirection: vec3f, sunDirection: vec3f) -> vec4f {
    var currentPosition = rayOrigin;
    var result = vec4(0.);
    var marchedInside = false;

    for (var i = 0; i < MAX_STEPS; i++) {
        let density = scene(currentPosition);

        if (density > 0) {
            let diffuse = clamp((density - scene(currentPosition + sunDirection * 0.3)) / 0.3, 0.0, 1.0);
            let lin = vec3(0.6, 0.6, 0.75) * 1.1 + vec3(1.0, 0.6, 0.3) * 0.8 * diffuse;

            var color = vec4(0.0);
            const white = vec3(0.0, 0.0, 0.0);
            const black = vec3(1.0, 1.0, 1.0);


            color += vec4(vec3(1.0 - density), density); // both lines are equivalent
//            color += vec4(mix(black, white, density), density);

            // tint cloud
            color = vec4(color.rgb * lin, color.a);

            // premultiplied alpha
            color = vec4(color.rgb * color.a, color.a);

            result += color * (1.0 - result.a);
        }

        currentPosition = currentPosition + MARCH_SIZE * normalize(rayDirection);
    }

    return result;
}

fn applyCameraRotation(p: vec3f) -> vec3f {
    let angle = uniforms.elapsedTime * 0.0; //* 0.0005;
    let p1 = rotateXZ(p, angle);
    let p2 = rotateYZ(p1, 70.0);
    return p2;
}

@fragment
fn fs(in: VertexOut) -> @location(0) vec4f {
    var sunPosition: vec3f = vec3(2.0, 1.5, 0.5);
//    var sunPosition: vec3f = vec3(2.0 * sin(uniforms.elapsedTime * 0.001), 1.5, 0.5); // sun from right to left
    var sunDirection: vec3f = normalize(sunPosition);

    var uv = vec2f(in.uv);
    var centeredUV = uv - vec2f(0.5);

    var camera = vec3f(0.0, 0.0, -5.0);
    camera = applyCameraRotation(camera);
    let rayDir = normalize(-normalize(camera) + applyCameraRotation(vec3f(centeredUV, 0.0)));

    var offset = fract(textureSampleLevel(blueNoiseTexture, texSampler, in.pos.xy / 1024.0, 0.0).r);
    offset *= MARCH_SIZE;

    let cloudColor = rayMarch(camera + rayDir * offset, rayDir, sunDirection);

    var skyColor = vec3(0.7, 0.7, 0.9);
    skyColor -= 0.8 * vec3(0.9, 0.75, 0.9) * centeredUV.y;

    let sun = clamp(dot(sunDirection, rayDir), 0.0, 1.0);
    skyColor += vec3(0.5,0.25,0.15) * pow(sun, 1.0);

    let color = skyColor * (1.0 - cloudColor.a) + cloudColor.rgb;
    return vec4(color.rgb, 1.0);

//    const black = vec4(0.0, 0.0, 0.0, 1.0);
//    const white = vec4(1.0, 1.0, 1.0, 1.0);

//    return select(black, white, (fract(uv.x * 10.0) > 0.5 && fract(uv.y * 10.0) > 0.5) || (fract(uv.x * 10.0) < 0.5 && fract(uv.y * 10.0) < 0.5));
}