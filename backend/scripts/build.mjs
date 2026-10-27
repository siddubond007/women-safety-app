import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

function runNodeScript(scriptPath, args, env) {
  const result = spawnSync(
    process.execPath,
    [resolve(scriptPath), ...args],
    {
      cwd: process.cwd(),
      env,
      stdio: "inherit",
      windowsHide: true,
    },
  );

  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }

  if (result.signal) {
    console.error(`Build subprocess terminated by signal: ${result.signal}`);
    process.exit(1);
  }

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

// Prisma loads prisma.config.ts even for client generation. Keep only that
// child process in the local/offline schema-generation context so it can use
// the placeholder datasource and never needs the staging migrator URL.
// The parent build process and the eventual Render runtime keep their original
// environment; this script does not execute any database migration command.
console.log(
  "Generating Prisma Client in isolated offline build context (SAKHI_ENV=dev).",
);
const prismaGenerationEnv = {
  ...process.env,
  SAKHI_ENV: "dev",
};
delete prismaGenerationEnv.SAKHI_MIGRATOR_DATABASE_URL;
runNodeScript("node_modules/prisma/build/index.js", ["generate"], prismaGenerationEnv);

// TypeScript compilation inherits the caller environment. It does not need
// database access or migration credentials.
console.log("Compiling NestJS backend.");
runNodeScript("node_modules/typescript/bin/tsc", ["-p", "tsconfig.build.json"], {
  ...process.env,
});
