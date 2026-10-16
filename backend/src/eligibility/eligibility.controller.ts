import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Post,
} from "@nestjs/common";
import {
  ApiBearerAuth,
  ApiConflictResponse,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiTags,
} from "@nestjs/swagger";
import {
  CreateEligibilitySupportRequestDto,
  StartEligibilityVerificationDto,
} from "./eligibility.dto.js";
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
  start(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto?: StartEligibilityVerificationDto,
  ) {
    return this.eligibility.start(authorization, dto);
  }

  @Post("support-requests")
  @ApiBearerAuth()
  @ApiCreatedResponse({
    description:
      "Records a category-only eligibility support request; this does not verify eligibility.",
  })
  createSupportRequest(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreateEligibilitySupportRequestDto,
  ) {
    return this.eligibility.createSupportRequest(authorization, dto);
  }

  @Get("support-requests")
  @ApiBearerAuth()
  @ApiOkResponse({
    description: "Lists support requests owned by the authenticated account.",
  })
  listSupportRequests(
    @Headers("authorization") authorization: string | undefined,
  ) {
    return this.eligibility.listSupportRequests(authorization);
  }
}
