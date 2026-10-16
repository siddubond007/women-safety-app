import {
  Body,
  Controller,
  Get,
  Headers,
  Patch,
} from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiTags,
} from "@nestjs/swagger";
import { ProfileService } from "./profile.service.js";
import { UpdateMyProfileDto } from "./profile.dto.js";

@ApiTags("profile")
@ApiBearerAuth()
@Controller("profile")
export class ProfileController {
  constructor(private readonly profile: ProfileService) {}

  @Get("me")
  @ApiOkResponse({
    description: "Returns the authenticated member's own profile.",
  })
  getMe(@Headers("authorization") authorization: string | undefined) {
    return this.profile.getMyProfile(authorization);
  }

  @Patch("me")
  @ApiOkResponse({
    description: "Updates allowed fields on the authenticated member's profile.",
  })
  updateMe(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: UpdateMyProfileDto,
  ) {
    return this.profile.updateMyProfile(authorization, dto);
  }
}
