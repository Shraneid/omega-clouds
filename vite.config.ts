import { defineConfig } from "vite";

export default defineConfig({
    base: "/omega-clouds/",
    plugins: [
        {
            name: "watch-shaders",
            configureServer(server) {
                server.watcher.on("change", (file) => {
                    console.log(`file changed: ${file}`);
                    if (file.includes("shaders") || file.endsWith(".ts")) {
                        server.hot.send({ type: "full-reload" });
                    }
                });
            },
        },
    ],
});
