import { createHash } from "node:crypto";
import { afterEach, describe, expect, it } from "vitest";
import { Module2Service } from "../src/module2/module2.service.js";
import {
  SAKHI_42_WELLNESS_TRACKS,
  SAKHI_SELECTABLE_VOICES,
  synthesizeDeterministicLoopableWav,
} from "../src/module2/wellness-audio-catalog.helper.js";

const originalCdn = process.env.SAKHI_WELLNESS_AUDIO_CDN_BASE_URL;

afterEach(() => {
  if (originalCdn === undefined) delete process.env.SAKHI_WELLNESS_AUDIO_CDN_BASE_URL;
  else process.env.SAKHI_WELLNESS_AUDIO_CDN_BASE_URL = originalCdn;
});

describe("Gemini wellness audio catalogue and delivery", () => {
  it("exposes 42 unique catalogue tracks and five configured neural voice profiles", () => {
    expect(SAKHI_42_WELLNESS_TRACKS).toHaveLength(42);
    expect(new Set(SAKHI_42_WELLNESS_TRACKS.map((track) => track.trackId)).size).toBe(42);
    expect(SAKHI_SELECTABLE_VOICES.map((voice) => voice.voiceId)).toEqual([
      "V22", "V24", "V26", "V30", "V01",
    ]);
    for (const track of SAKHI_42_WELLNESS_TRACKS) {
      expect(track.sha256Checksum).toMatch(/^[a-f0-9]{64}$/);
      expect(track.objectPath).toMatch(/^wellness-audio\/v1\/[A-Za-z0-9_., -]+\.mp3$/);
      expect(track.byteSize).toBeGreaterThan(0);
    }
  });

  it("creates deterministic, checksum-verifiable WAV fallback bytes for a catalogue track", () => {
    const track = SAKHI_42_WELLNESS_TRACKS[0]!;
    const first = synthesizeDeterministicLoopableWav(track, 4);
    const second = synthesizeDeterministicLoopableWav(track, 4);
    expect(first.mimeType).toBe("audio/wav");
    expect(first.buffer.subarray(0, 4).toString("ascii")).toBe("RIFF");
    expect(first.buffer.subarray(8, 12).toString("ascii")).toBe("WAVE");
    expect(first.buffer.equals(second.buffer)).toBe(true);
    expect(first.sha256Checksum).toBe(createHash("sha256").update(first.buffer).digest("hex"));
    expect(first.sha256Checksum).toBe(second.sha256Checksum);
  });

  it("serves fallback audio bytes and reuses the bounded backend memory cache", async () => {
    delete process.env.SAKHI_WELLNESS_AUDIO_CDN_BASE_URL;
    const service = new Module2Service({} as any, {} as any);
    const first = await service.streamWellnessAudioTrack("M01");
    const second = await service.streamWellnessAudioTrack("M01");
    expect(first.cacheStatus).toBe("MISS");
    expect(second.cacheStatus).toBe("HIT");
    expect(first.buffer.equals(second.buffer)).toBe(true);
    expect(first.sha256Checksum).toBe(second.sha256Checksum);
    expect(first.contentType).toBe("audio/wav");
  });

  it("rejects unknown track IDs rather than serving arbitrary object paths", async () => {
    const service = new Module2Service({} as any, {} as any);
    await expect(service.streamWellnessAudioTrack("../../private")).rejects.toThrow();
  });
  it("reports device TTS and the real CDN/fallback mode without claiming unimplemented cloud neural synthesis", async () => {
    delete process.env.SAKHI_WELLNESS_AUDIO_CDN_BASE_URL;
    const service = new Module2Service({} as any, {} as any);
    const catalog = await service.getWellnessAudioCatalog();
    expect(catalog.voiceSynthesisProvider).toMatchObject({
      activeMode: "DEVICE_NATIVE_TTS",
      cloudNeuralConfigured: false,
    });
    expect(catalog.audioDelivery).toMatchObject({
      mode: "PROCEDURAL_WAV_FALLBACK",
      remoteCdnConfigured: false,
      backendMemoryCache: { maxCachedTracks: 6, maxCacheBytes: 15 * 1024 * 1024, ttlHours: 168 },
    });
  });

});
