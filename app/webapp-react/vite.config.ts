import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'node:path';

// Assets ship under /react-app/ so the Express strangler can mount them
// ahead of the legacy static middleware without any path collisions.
export default defineConfig({
    base: '/react-app/',
    plugins: [react()],
    resolve: {
        alias: {
            '@': path.resolve(__dirname, './src')
        }
    },
    build: {
        outDir: 'dist',
        sourcemap: false
    },
    test: {
        environment: 'jsdom',
        globals: true,
        setupFiles: './vitest.setup.ts',
        css: false
    }
});
