import { validate } from "class-validator";
import { describe, expect, it } from "vitest";
import {
  CreateCommunityEventDto,
  CreateCommunityGroupDto,
  CreatePostDto,
  UpdateProfileDto,
} from "../src/module2/module2.dto.js";

const assignDto = <T extends object>(type: new () => T, value: object): T =>
  Object.assign(new type(), value);

describe("Module 2 request DTO validation", () => {
  it("accepts profile updates using only the supported profile fields", async () => {
    const dto = assignDto(UpdateProfileDto, {
      displayName: "Sakhi Member",
      email: "member@example.com",
      bio: "Learning and growing",
      locationCity: "Tirupati",
      interests: ["Wellness", "Women in Tech"],
      profilePhotoRef: "profile/2f6f7fa1/avatar.webp",
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it("rejects malformed email and untrusted photo references", async () => {
    const dto = assignDto(UpdateProfileDto, {
      email: "not-an-email",
      profilePhotoRef: "../../private/photo.png",
    });

    const errors = await validate(dto);
    const invalidProperties = new Set(errors.map((error) => error.property));
    expect(invalidProperties.has("email")).toBe(true);
    expect(invalidProperties.has("profilePhotoRef")).toBe(true);
  });

  it("rejects unsupported community group visibility values", async () => {
    const dto = assignDto(CreateCommunityGroupDto, {
      name: "Women in Technology",
      visibility: "PUBLIC",
    });

    const errors = await validate(dto);
    expect(errors.some((error) => error.property === "visibility")).toBe(true);
  });

  it("requires a valid group event time format", async () => {
    const dto = assignDto(CreateCommunityEventDto, {
      groupId: "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41",
      title: "Community meetup",
      description: "A member-led meetup.",
      startsAt: "not-a-date",
      endsAt: "also-not-a-date",
    });

    const errors = await validate(dto);
    expect(errors.some((error) => error.property === "startsAt")).toBe(true);
    expect(errors.some((error) => error.property === "endsAt")).toBe(true);
  });

  it("rejects unsupported post audiences", async () => {
    const dto = assignDto(CreatePostDto, {
      body: "Hello Sakhi",
      audience: "EVERYONE",
    });

    const errors = await validate(dto);
    expect(errors.some((error) => error.property === "audience")).toBe(true);
  });
});
