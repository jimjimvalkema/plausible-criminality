import { defineConfig } from 'vite';

export default defineConfig({
    build: {
        target: 'esnext', // This enables top-level await
    },
    optimizeDeps: {
        esbuildOptions: {
            target: 'esnext', // Needed for top-level await
        },
    },
    // // Add manual handling for the @aztec/bb.js package
    // resolve: {
    //     alias: {
    //         '@aztec/bb.js': '@aztec/bb.js/dest/browser/index.js',
    //     },
    // },
});