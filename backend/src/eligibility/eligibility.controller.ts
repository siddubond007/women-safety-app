import { Controller, Get, Headers, HttpCode, Post } from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiOkResponse,
  ApiTags,
} from "@nestjs/swagger";
import { EligibilityService } from "./eligibility.service.js";

@ApiTags("eligibility")
@Controller("eligibility")
export class EligibilityController {
  constructor(private readonly eligibility: EligibilityService) {}

  @Get("configuration")
  @ApiOkResponse({ description: "Current approved configuration, if any." })
  configuration() {
    return this.eligibility.configuration();
  }

  @Get("status")
  @ApiBearerAuth()
  @ApiOkResponse({ description: "Trusted account eligibility status." })
  status(@Headers("authorization") authorization: string | undefined) {
    return this.eligibility.status(authorization);
  }

  @Post("start")
  @HttpCode(200)
  @ApiBearerAuth()
  @ApiConflictResponse({
    description:
      "No authorised identity provider or approved eligibility policy is configured.",
  })
  start(@Headers("authorization") authorization: string | undefined) {
    return this.eligibility.start(authorization);
  }
}
