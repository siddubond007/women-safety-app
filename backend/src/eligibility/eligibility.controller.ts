import {
  BadRequestException,
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
  ELIGIBILITY_SUPPORT_REQUEST_CATEGORIES,
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
    // Keep this endpoint safe even if a test harness or an alternate Nest
    // bootstrap omits the global ValidationPipe. Only a category is accepted;
    // do not accept free-text claims or uploaded identity evidence here.
    if (
      !dto ||
      typeof dto !== "object" ||
      Array.isArray(dto) ||
      typeof dto.category !== "string" ||
      !ELIGIBILITY_SUPPORT_REQUEST_CATEGORIES.includes(
        dto.category as (typeof ELIGIBILITY_SUPPORT_REQUEST_CATEGORIES)[number],
      )
    ) {
      throw new BadRequestException({
        code: "invalid_eligibility_support_category",
        message: "Choose a supported eligibility support request category.",
      });
    }

    const unexpectedKeys = Object.keys(dto).filter((key) => key !== "category");
    if (unexpectedKeys.length > 0) {
      throw new BadRequestException({
        code: "unsupported_eligibility_support_fields",
        message: "Only a support request category is accepted. Do not submit identity documents or free-text identity information.",
      });
    }

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
