import "reflect-metadata";
import type { INestApplication } from "@nestjs/common";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";
import { Module2Controller } from "../src/module2/module2.controller.js";
import {
  CreateCommunityPostDto,
  UpdateModule2ProfileDto,
  UpdateNotificationPreferenceDto,
  UpdatePrivacyPreferenceDto,
} from "../src/module2/module2.dto.js";
import { Module2Service } from "../src/module2/module2.service.js";

describe("Module 2 API contract", () => {
  let app: INestApplication | undefined;
  const service = {
    bootstrap: vi.fn(),
    updateProfile: vi.fn(),
    createPost: vi.fn(),
    togglePostLike: vi.fn(),
    togglePostSave: vi.fn(),
    addPostComment: vi.fn(),
    toggleFollow: vi.fn(),
    updatePrivacyPreference: vi.fn(),
    updateNotificationPreference: vi.fn(),
    recordSafetyEvent: vi.fn(),
    addEmergencyContact: vi.fn(),
    toggleTwoFactor: vi.fn(),
    updateSecurityPin: vi.fn(),
    reportUserOrPost: vi.fn(),
    toggleBlockedUser: vi.fn(),
  };

  afterEach(async () => {
    if (app) {
      await app.close();
      app = undefined;
    }
    vi.resetAllMocks();
  });

  async function createApp() {
    Reflect.defineMetadata("design:paramtypes", [Module2Service], Module2Controller);
    Reflect.defineMetadata(
      "design:paramtypes",
      [String],
      Module2Controller.prototype,
      "bootstrap",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [String, UpdateModule2ProfileDto],
      Module2Controller.prototype,
      "updateProfile",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [String, CreateCommunityPostDto],
      Module2Controller.prototype,
      "createPost",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [String, UpdatePrivacyPreferenceDto],
      Module2Controller.prototype,
      "updatePrivacy",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [String, UpdateNotificationPreferenceDto],
      Module2Controller.prototype,
      "updateNotification",
    );

    const module = await Test.createTestingModule({
      controllers: [Module2Controller],
      providers: [{ provide: Module2Service, useValue: service }],
    }).compile();

    const testApp = module.createNestApplication();
    testApp.setGlobalPrefix("api/v1");
    testApp.useGlobalPipes(createGlobalValidationPipe());
    await testApp.init();
    app = testApp;
    return testApp;
  }

  it("returns the bootstrap payload for all 12 screens", async () => {
    service.bootstrap.mockResolvedValue({
      user: {
        displayName: "Siddhu",
        username: "@siddhu",
        postsCount: 124,
        followersCount: 560,
        followingCount: 312,
      },
      communityPosts: [],
      exploreRecommendedPosts: [],
      profilePosts: [],
    });

    const testApp = await createApp();
    const response = await request(testApp.getHttpServer())
      .get("/api/v1/module2/bootstrap")
      .set("Authorization", "Bearer valid-test-token")
      .expect(200);

    expect(response.body.user.displayName).toBe("Siddhu");
    expect(service.bootstrap).toHaveBeenCalledWith("Bearer valid-test-token");
  });

  it("validates and forwards profile updates", async () => {
    service.updateProfile.mockResolvedValue({
      displayName: "Siddhu",
      username: "@siddhu",
      bio: "Updated bio",
      location: "Bangalore, India",
      interests: ["Mental Wellness", "WomenInTech"],
    });

    const testApp = await createApp();
    await request(testApp.getHttpServer())
      .put("/api/v1/module2/profile")
      .set("Authorization", "Bearer valid-test-token")
      .send({
        displayName: "Siddhu",
        bio: "Updated bio",
        location: "Bangalore, India",
        interests: ["Mental Wellness", "WomenInTech"],
      })
      .expect(200);

    expect(service.updateProfile).toHaveBeenCalledWith("Bearer valid-test-token", {
      displayName: "Siddhu",
      bio: "Updated bio",
      location: "Bangalore, India",
      interests: ["Mental Wellness", "WomenInTech"],
    });
  });

  it("validates privacy and notification preference updates", async () => {
    service.updatePrivacyPreference.mockResolvedValue({
      settingId: "view_profile",
      selectedValue: "Followers only",
    });
    service.updateNotificationPreference.mockResolvedValue({
      prefId: "marketing_updates",
      isEnabled: true,
    });

    const testApp = await createApp();
    await request(testApp.getHttpServer())
      .put("/api/v1/module2/privacy")
      .set("Authorization", "Bearer valid-test-token")
      .send({
        settingId: "view_profile",
        selectedValue: "Followers only",
      })
      .expect(200);

    await request(testApp.getHttpServer())
      .put("/api/v1/module2/notifications")
      .set("Authorization", "Bearer valid-test-token")
      .send({
        prefId: "marketing_updates",
        isEnabled: true,
      })
      .expect(200);

    expect(service.updatePrivacyPreference).toHaveBeenCalledOnce();
    expect(service.updateNotificationPreference).toHaveBeenCalledOnce();
  });
});
