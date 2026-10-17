import { Body, Controller, Get, Headers, HttpCode, Post } from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiOkResponse,
  ApiTags,
} from "@nestjs/swagger";
import { EligibilityService } from "./eligibility.service.js";
import { StartManualReviewDto } from "./eligibility.dto.js";

@ApiTags("eligibility")
@Controller("eligibility")
export class EligibilityController {
  constructor(private readonly eligibility: EligibilityService) {}

  @Get("configuration")
  @ApiOkResponse({ description: "Provider readiness and local manual-review policy readiness." })
  configuration() {
    return this.eligibility.configuration();
  }

  @Get("status")
  @ApiBearerAuth()
  @ApiOkResponse({ description: "Provider readiness and the authenticated member's canonical eligibility decision." })
  status(@Headers("authorization") authorization: string | undefined) {
    return this.eligibility.status(authorization);
  }

  @Post("start")
  @HttpCode(200)
  @ApiBearerAuth()
  @ApiConflictResponse({
    description: "Provider verification is unavailable. A manual request can only be created after its policy and evidence procedure are explicitly enabled.",
  })
  start(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: StartManualReviewDto,
  ) {
    return this.eligibility.start(authorization, dto);
  }
}
