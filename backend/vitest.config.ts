import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["test/**/*.spec.ts"],
    clearMocks: true,
    restoreMocks: true,
    testTimeout: 10_000,
    pool: "threads",
    maxWorkers: 1,
    fileParallelism: false,
  },
});
