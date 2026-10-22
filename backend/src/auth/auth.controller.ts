import { Body, Controller, Get, Headers, HttpCode, Post } from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiTags,
} from "@nestjs/swagger";
import { AuthenticationService } from "./auth.service.js";
import {
  CreateProfileDto,
  RequestOtpDto,
  ResendOtpDto,
  VerifyOtpDto,
} from "./auth.dto.js";

@ApiTags("authentication")
@Controller("auth")
export class AuthController {
  constructor(private readonly auth: AuthenticationService) {}

  @Get("registration-policy")
  @ApiOkResponse({
    description: "Returns the active minimum registration age policy.",
  })
  registrationPolicy() {
    return this.auth.getRegistrationPolicy();
  }

  @Post("otp/request")
  @HttpCode(200)
  @ApiOkResponse({ description: "Created a local development OTP challenge." })
  requestOtp(@Body() dto: RequestOtpDto) {
    return this.auth.requestOtp(dto);
  }

  @Post("otp/resend")
  @HttpCode(200)
  @ApiOkResponse({ description: "Replaced a prior development OTP challenge." })
  resendOtp(@Body() dto: ResendOtpDto) {
    return this.auth.resendOtp(dto.challengeId);
  }

  @Post("otp/verify")
  @HttpCode(200)
  @ApiOkResponse({ description: "Validated a one-time development code." })
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.auth.verifyOtp(dto);
  }

  @Post("profile")
  @HttpCode(200)
  @ApiBearerAuth()
  @ApiOkResponse({
    description: "Persisted profile and draft policy acknowledgement.",
  })
  createProfile(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreateProfileDto,
  ) {
    return this.auth.createProfile(authorization, dto);
  }

  @Get("me")
  @ApiBearerAuth()
  @ApiOkResponse({
    description: "Returns the authenticated development account.",
  })
  me(@Headers("authorization") authorization: string | undefined) {
    return this.auth.getCurrentAccount(authorization);
  }

  @Post("logout")
  @HttpCode(200)
  @ApiBearerAuth()
  @ApiOkResponse({ description: "Revoked the current development session." })
  logout(@Headers("authorization") authorization: string | undefined) {
    return this.auth.logout(authorization);
  }
}
