import "./style.css";
import { mat4LookAt, mat4Perspective } from "./helper.ts";

const params = new URLSearchParams(window.location.search);
const DISTANCE_TO_CUBE = parseFloat(params.get("distance") ?? "2.2");

let startTime: number;
let lastFrameTime: number;

let yaw = 0;
let pitch = 0.2;
let mouseDown = false;
let mousePos = { x: 0, y: 0 };
let mouseDelta = { x: 0, y: 0 };

// getting the HTML canvas
const canvas: HTMLCanvasElement = document.getElementById(
    "GLCanvas",
)! as HTMLCanvasElement;

// SETTING UP MOUSE MOVEMENT
canvas.addEventListener("mousedown", () => {
    mouseDown = true;
});
canvas.addEventListener("mouseup", () => {
    mouseDown = false;
    mouseDelta = { x: 0, y: 0 };
});
canvas.addEventListener("mousemove", (e) => {
    if (!mouseDown) {
        mousePos = { x: -1, y: -1 };
        return;
    }
    const rect = canvas.getBoundingClientRect();

    mouseDelta = { x: e.movementX / rect.width, y: -e.movementY / rect.width };
    mousePos = { x: e.offsetX / rect.width, y: 1 - e.offsetY / rect.width };
});

// SETTING UP TOUCH INPUT
let lastTouchPos = { x: 0, y: 0 };
canvas.addEventListener(
    "touchstart",
    (e) => {
        e.preventDefault();
        mouseDown = true;
        const rect = canvas.getBoundingClientRect();
        const touch = e.touches[0];
        lastTouchPos = { x: touch.clientX, y: touch.clientY };
        mousePos = {
            x: (touch.clientX - rect.left) / rect.width,
            y: 1 - (touch.clientY - rect.top) / rect.height,
        };
    },
    { passive: false },
);

canvas.addEventListener(
    "touchend",
    (e) => {
        e.preventDefault();
        mouseDown = false;
        mouseDelta = { x: 0, y: 0 };
    },
    { passive: false },
);

canvas.addEventListener(
    "touchmove",
    (e) => {
        e.preventDefault();
        const rect = canvas.getBoundingClientRect();
        const touch = e.touches[0];
        mouseDelta = {
            x: (touch.clientX - lastTouchPos.x) / rect.width,
            y: -(touch.clientY - lastTouchPos.y) / rect.height,
        };
        mousePos = {
            x: (touch.clientX - rect.left) / rect.width,
            y: 1 - (touch.clientY - rect.top) / rect.height,
        };
        lastTouchPos = { x: touch.clientX, y: touch.clientY };
    },
    { passive: false },
);

// MAIN SETUP FOR RENDERING
const adapter = await navigator.gpu?.requestAdapter();
const device = await adapter?.requestDevice();

if (!device) {
    throw Error("No gpu detected");
}

const context = canvas.getContext("webgpu");
if (!context) {
    throw Error("Error getting the context");
}

const devicePixelRatio = window.devicePixelRatio;
canvas.width = canvas.clientWidth * devicePixelRatio;
canvas.height = canvas.clientHeight * devicePixelRatio;

const presentationFormat = navigator.gpu.getPreferredCanvasFormat();
context.configure({
    device: device,
    format: presentationFormat,
});
// END MAIN SETUP FOR RENDERING

// LOAD TEXTURES
const loadTextureToBitmap = async (path: string) => {
    const textureResponse = await fetch(path);
    const textureBlob = await textureResponse.blob();

    return await createImageBitmap(textureBlob);
};

const getSamplerAndTexture = async (path: string, label: string) => {
    const bitmap = await loadTextureToBitmap(path);

    const texture = device.createTexture({
        label,
        size: [bitmap.width, bitmap.height, 1],
        format: "rgba8unorm",
        usage:
            GPUTextureUsage.TEXTURE_BINDING |
            GPUTextureUsage.COPY_DST |
            GPUTextureUsage.RENDER_ATTACHMENT,
    });

    device.queue.copyExternalImageToTexture({ source: bitmap }, { texture }, [
        bitmap.width,
        bitmap.height,
    ]);

    const sampler = device.createSampler({
        minFilter: "linear",
        magFilter: "linear",
        addressModeU: "repeat",
        addressModeV: "repeat",
    });

    return { sampler, texture };
};

// LOAD SHADERS
const loadWGSL = async (path: string) => {
    const response = await fetch(path, { cache: "no-store" });
    if (!response.ok) {
        throw new Error(`Failed to load shader: ${path}`);
    }
    return response.text();
};

const loadShaderModule = async (path: string): Promise<GPUShaderModule> => {
    const code = await loadWGSL(path);
    return device.createShaderModule({ code });
};

const vertexShader = await loadShaderModule("shaders/vertex.wgsl");
const fragmentShader = await loadShaderModule("shaders/fragment.wgsl");
// END LOAD SHADERS

// BUFFERS
const vertices = new Float32Array([
    -0.5,
    -0.5,
    -0.5, // 0
    0.5,
    -0.5,
    -0.5, // 1
    0.5,
    0.5,
    -0.5, // 2
    -0.5,
    0.5,
    -0.5, // 3
    -0.5,
    -0.5,
    0.5, // 4
    0.5,
    -0.5,
    0.5, // 5
    0.5,
    0.5,
    0.5, // 6
    -0.5,
    0.5,
    0.5, // 7
]);
const indices = new Uint16Array([
    0,
    1,
    2,
    0,
    2,
    3, // -Z
    5,
    4,
    7,
    5,
    7,
    6, // +Z
    4,
    0,
    3,
    4,
    3,
    7, // -X
    1,
    5,
    6,
    1,
    6,
    2, // +X
    3,
    2,
    6,
    3,
    6,
    7, // +Y
    4,
    5,
    1,
    4,
    1,
    0, // -Y
]);

const uniformBuffer = device.createBuffer({
    label: "Uniform Buffer",
    size: 160, // 152 + 8 padding, rounded at 16 bytes
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
});

const vertexBuffer = device.createBuffer({
    label: "VertexBuffer",
    size: vertices.byteLength,
    usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
});

const indexBuffer = device.createBuffer({
    label: "IndexBuffer",
    size: indices.byteLength,
    usage: GPUBufferUsage.INDEX | GPUBufferUsage.COPY_DST,
});
// END BUFFERS

// LOAD TEXTURES
const { sampler: noiseSampler, texture: noiseTexture } =
    await getSamplerAndTexture("textures/uniformclouds.jpg", "noiseTexture");
// END LOAD TEXTURES

// BIND GROUP LAYOUTS
const renderBindGroupLayout = device.createBindGroupLayout({
    label: "Render Bind Group Layout",
    entries: [
        {
            binding: 0,
            visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
            buffer: { type: "uniform" },
        },
        {
            binding: 1,
            visibility: GPUShaderStage.FRAGMENT,
            sampler: {},
        },
        {
            binding: 2,
            visibility: GPUShaderStage.FRAGMENT,
            texture: {},
        },
    ],
});
// END BIND GROUP LAYOUTS

// PIPELINES SETUP
const renderPipelineLayout = device.createPipelineLayout({
    label: "Render Pipeline Layout",
    bindGroupLayouts: [renderBindGroupLayout],
});

const renderPipeline = device.createRenderPipeline({
    label: "Render Pipeline",
    layout: renderPipelineLayout,
    primitive: {
        topology: "triangle-list",
        cullMode: "back",
        frontFace: "cw",
    },
    vertex: {
        module: vertexShader,
        buffers: [
            {
                arrayStride: 12, // 3 floats * 4 bytes
                attributes: [
                    {
                        shaderLocation: 0,
                        offset: 0,
                        format: "float32x3",
                    },
                ],
            },
        ],
    },
    fragment: {
        module: fragmentShader,
        targets: [
            {
                format: presentationFormat,
                blend: {
                    color: {
                        srcFactor: "src-alpha",
                        dstFactor: "one-minus-src-alpha",
                        operation: "add",
                    },
                    alpha: {
                        srcFactor: "one",
                        dstFactor: "one-minus-src-alpha",
                        operation: "add",
                    },
                },
            },
        ],
    },
});

// BIND GROUPS
const renderBindGroup = device.createBindGroup({
    label: "Render Bind Group",
    layout: renderBindGroupLayout,
    entries: [
        {
            binding: 0,
            resource: { buffer: uniformBuffer },
        },
        {
            binding: 1,
            resource: noiseSampler,
        },
        {
            binding: 2,
            resource: noiseTexture.createView(),
        },
    ],
});

// Render Pass Descriptor
const renderPassDescriptor = {
    label: "Render Pass Description",
    colorAttachments: [
        {
            clearValue: [114 / 255, 214 / 255, 255 / 255, 1],
            loadOp: "clear",
            storeOp: "store",
            view: context.getCurrentTexture().createView(),
        },
    ],
};
// END PIPELINES SETUP

// SENDING BUFFERS TO GPU
device.queue.writeBuffer(vertexBuffer, 0, vertices);
device.queue.writeBuffer(indexBuffer, 0, indices);

// RENDER
const render = (deltaTime: number, elapsedTime: number) => {
    renderPassDescriptor.colorAttachments[0].view = context
        .getCurrentTexture()
        .createView();

    const encoder = device.createCommandEncoder({ label: "command encoder" });

    // MVP Matrices setup
    const aspect = canvas.width / canvas.height;

    // ORBITING CAMERA
    // const angle = elapsedTime / 1000;
    // const cameraPos: [number, number, number] = [
    //     Math.sin(angle) * DISTANCE_TO_CUBE,
    //     0.5,
    //     Math.cos(angle) * DISTANCE_TO_CUBE,
    // ];

    // CAMERA MOVED WITH MOUSE
    yaw -= mouseDelta.x * 2;
    pitch -= mouseDelta.y * 2;
    pitch = Math.max(-Math.PI / 2 + 0.01, Math.min(Math.PI / 2 - 0.01, pitch)); // clamp pitch
    mouseDelta = { x: 0, y: 0 };
    const cameraPos: [number, number, number] = [
        Math.sin(yaw) * Math.cos(pitch) * DISTANCE_TO_CUBE,
        Math.sin(pitch) * DISTANCE_TO_CUBE,
        Math.cos(yaw) * Math.cos(pitch) * DISTANCE_TO_CUBE,
    ];

    // MVP Matrices
    const view = mat4LookAt(cameraPos, [0, 0, 0], [0, 1, 0]);
    const projection = mat4Perspective(Math.PI / 4, aspect, 0.1, 1000.0);

    // UNIFORMS
    device.queue.writeBuffer(uniformBuffer, 0, view);
    device.queue.writeBuffer(uniformBuffer, 64, projection);
    device.queue.writeBuffer(
        uniformBuffer,
        128,
        new Float32Array([...cameraPos, 0]),
    );
    device.queue.writeBuffer(
        uniformBuffer,
        144,
        new Float32Array([deltaTime / 1000, elapsedTime]),
    );

    // RENDER PASS
    // @ts-ignore
    const renderPass = encoder.beginRenderPass(renderPassDescriptor);
    renderPass.setPipeline(renderPipeline);
    renderPass.setVertexBuffer(0, vertexBuffer);
    renderPass.setIndexBuffer(indexBuffer, "uint16");
    renderPass.setBindGroup(0, renderBindGroup);
    renderPass.drawIndexed(36);
    renderPass.end();

    device.queue.submit([encoder.finish()]);
};

const renderLoop = (timestamp: number) => {
    if (startTime === undefined) {
        startTime = timestamp;
        lastFrameTime = timestamp;
    }
    const elapsedTime = timestamp - startTime;
    const deltaTime = timestamp - lastFrameTime;

    render(deltaTime, elapsedTime);

    lastFrameTime = timestamp;
    console.log("looping");
    requestAnimationFrame(renderLoop);
};

requestAnimationFrame(renderLoop);
// END RENDER
