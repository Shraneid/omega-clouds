import { defineConfig } from "vite";

export default defineConfig({
    base: "/omega-clouds/",
    plugins: [
        {
            name: "watch-shaders",
            configureServer(server) {
                server.watcher.on("change", (file) => {
                    console.log(file);
                    if (file.includes("shaders")) {
                        server.hot.send({ type: "full-reload" });
                    }
                });
            },
        },
    ],
});
