import { randomUUID } from "node:crypto";
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { AuthenticationService } from "../auth/auth.service.js";
import { PrismaService } from "../database/prisma.service.js";
import type { UpdateMyProfileDto } from "./profile.dto.js";

const profileSelect = {
  displayName: true,
  email: true,
  bio: true,
  city: true,
  updatedAt: true,
} as const;

type MutableProfileFields = {
  displayName?: string;
  email?: string | null;
  bio?: string | null;
  city?: string | null;
};

@Injectable()
export class ProfileService {
  constructor(
    private readonly authentication: AuthenticationService,
    private readonly prisma: PrismaService,
  ) {}

  async getMyProfile(authorization?: string) {
    const session =
      await this.authentication.authenticateAuthorization(authorization);
    const profile = await this.prisma.memberProfile.findUnique({
      where: { accountId: session.accountId },
      select: profileSelect,
    });

    if (!profile) {
      throw new NotFoundException(
        "No saved profile was found for this account. Complete registration first.",
      );
    }

    return { profile, isDemo: true };
  }

  async updateMyProfile(
    authorization: string | undefined,
    dto: UpdateMyProfileDto,
  ) {
    const session =
      await this.authentication.authenticateAuthorization(authorization);
    const data: MutableProfileFields = {};

    if (dto.displayName !== undefined) {
      if (dto.displayName === null) {
        throw new BadRequestException("Display name cannot be empty.");
      }
      const displayName = dto.displayName.trim();
      if (!displayName) {
        throw new BadRequestException("Display name cannot be empty.");
      }
      data.displayName = displayName;
    }
    if (Object.prototype.hasOwnProperty.call(dto, "email")) {
      data.email = this.normalizeOptional(dto.email);
    }
    if (Object.prototype.hasOwnProperty.call(dto, "bio")) {
      data.bio = this.normalizeOptional(dto.bio);
    }
    if (Object.prototype.hasOwnProperty.call(dto, "city")) {
      data.city = this.normalizeOptional(dto.city);
    }

    const changedFields = Object.keys(data).sort();
    if (changedFields.length === 0) {
      throw new BadRequestException(
        "Provide at least one profile field to update.",
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.memberProfile.findUnique({
        where: { accountId: session.accountId },
        select: { accountId: true },
      });
      if (!existing) {
        throw new NotFoundException(
          "No saved profile was found for this account. Complete registration first.",
        );
      }

      const profile = await tx.memberProfile.update({
        where: { accountId: session.accountId },
        data,
        select: profileSelect,
      });

      await tx.auditEvent.create({
        data: {
          actorType: "MEMBER",
          actorId: session.accountId,
          action: "member.profile.updated",
          targetType: "member_profile",
          targetId: session.accountId,
          outcome: "success",
          requestId: randomUUID(),
          // Record only changed field names. Never copy profile field values
          // into audit metadata.
          redactedMetadata: { changedFields },
        },
        select: { id: true },
      });

      return { profile, isDemo: true };
    });
  }

  private normalizeOptional(value: string | null | undefined): string | null {
    const normalized = value?.trim();
    return normalized ? normalized : null;
  }
}
