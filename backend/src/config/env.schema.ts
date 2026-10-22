/**
 * Compatibility export expected by the Gemini-restored AppModule.
 * Reuse the existing strict runtime/database/OTP validation rather than
 * introducing a second, potentially inconsistent validation implementation.
 */
export { validateRuntimeEnvironment as validateEnvironment } from "./database-target.js";
