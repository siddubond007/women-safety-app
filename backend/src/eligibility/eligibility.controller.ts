import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Post,
  Query,
  Res,
  Req,
} from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiOkResponse,
  ApiTags,
} from "@nestjs/swagger";
import type { Request, Response } from "express";
import { EligibilityService } from "./eligibility.service.js";
import { DecentroKycService } from "./decentro-kyc.service.js";
import {
  InitiateDecentroVerificationDto,
  LocalEligibilitySimulationDto,
  StagingDemoResultDto,
  StartManualReviewDto,
} from "./eligibility.dto.js";

type RequestWithRawBody = Request & { rawBody?: Buffer };

@ApiTags("eligibility")
@Controller(["eligibility", "verification"])
export class EligibilityController {
  constructor(
    private readonly eligibility: EligibilityService,
    private readonly decentro: DecentroKycService,
  ) {}

  @Get("configuration")
  @ApiOkResponse({
    description:
      "Provider readiness and local manual-review policy readiness. No provider secret values are returned.",
  })
  configuration() {
    return {
      ...this.eligibility.configuration(),
      ...this.decentro.configuration(),
    };
  }

  @Get("status")
  @ApiBearerAuth()
  @ApiOkResponse({
    description:
      "Canonical eligibility decision for the authenticated member.",
  })
  status(@Headers("authorization") authorization?: string) {
    return this.eligibility.status(authorization);
  }

  @Post("start")
  @HttpCode(200)
  @ApiBearerAuth()
  @ApiConflictResponse({
    description:
      "Creates a manual-review request only when its policy is explicitly enabled.",
  })
  start(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: StartManualReviewDto,
  ) {
    return this.eligibility.start(authorization, dto);
  }

  @Post(["decentro/initiate", "initiate"])
  @HttpCode(200)
  @ApiBearerAuth()
  initiateDecentroSession(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: InitiateDecentroVerificationDto,
  ) {
    return this.decentro.initiate(authorization, dto);
  }

  @Get("decentro/status")
  @ApiBearerAuth()
  decentroStatus(@Headers("authorization") authorization?: string) {
    return this.decentro.status(authorization);
  }

  @Post("decentro/staging-demo/start")
  @HttpCode(200)
  @ApiBearerAuth()
  startStagingDemoSession(
    @Headers("authorization") authorization: string | undefined,
  ) {
    return this.decentro.startStagingDemoSession(authorization);
  }

  @Post("decentro/staging-demo/result")
  @HttpCode(200)
  @ApiBearerAuth()
  stagingDemoResult(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: StagingDemoResultDto,
  ) {
    return this.decentro.simulateStagingDemoResult(authorization, dto);
  }

  @Post("decentro/local-simulator")
  @HttpCode(200)
  @ApiBearerAuth()
  localEligibilitySimulator(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: LocalEligibilitySimulationDto,
  ) {
    return this.decentro.simulateLocalResult(authorization, dto);
  }

  // The browser redirect carries only the random Sakhi reference. Demographic
  // values in redirect parameters are ignored; the server retrieves the result
  // from Decentro using the recorded transaction ID.
  @Get(["decentro/callback", "callback"])
  async browserCallback(
    @Query("referenceId") referenceId: string | undefined,
    @Res() response: Response,
  ) {
    response.setHeader("Cache-Control", "no-store");
    response.setHeader("Referrer-Policy", "no-referrer");
    response.setHeader("X-Content-Type-Options", "nosniff");
    response.setHeader("Content-Type", "text/html; charset=utf-8");

    let message =
      "Sakhi could not confirm the provider result yet. Return to the app and refresh status; no verification should be assumed.";
    try {
      await this.decentro.completeBrowserCallback(referenceId);
      message =
        "Sakhi checked the provider result. Return to the app and refresh verification status to see the saved decision.";
    } catch {
      // Do not leak provider payloads, member identifiers, or internal errors.
    }

    return response.status(200).send(
      "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta name=\"referrer\" content=\"no-referrer\"><title>Sakhi verification</title></head><body><main><h1>Return to Sakhi</h1><p>" +
        message +
        "</p><p>Sakhi does not display or retain your Aadhaar number or raw identity document on this page. Do not share identity documents or OTPs with anyone.</p></main></body></html>",
    );
  }

  // Decentro's server-to-server webhook must be configured to sign the raw
  // request body using the agreed webhook secret. No account ID or demographic
  // values from an unsigned request are accepted as verification evidence.
  @Post(["decentro/callback", "callback"])
  @HttpCode(200)
  callbackWebhook(
    @Req() request: RequestWithRawBody,
    @Headers("x-signature") signature?: string,
  ) {
    return this.decentro.handleSignedCallback(request.rawBody, signature);
  }
}
