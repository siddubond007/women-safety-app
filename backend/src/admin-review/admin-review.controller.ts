import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post } from "@nestjs/common";
import { ApiHeader, ApiOkResponse, ApiTags } from "@nestjs/swagger";
import { AdminReviewService } from "./admin-review.service.js";
import { ManualEligibilityDecisionDto } from "./admin-review.dto.js";

@ApiTags("admin-review")
@ApiHeader({ name: "X-Sakhi-Admin-Token", required: true, description: "Shared reviewer token for local dev/test only. Never use this mechanism in production." })
@Controller("admin-review")
export class AdminReviewController {
  constructor(private readonly review: AdminReviewService) {}

  @Get("session")
  @ApiOkResponse({ description: "Validates local dev/test reviewer access." })
  session(@Headers("x-sakhi-admin-token") token?: string) {
    return this.review.session(token);
  }

  @Get("queue")
  @ApiOkResponse({ description: "Lists explicit pending manual-review submissions." })
  queue(@Headers("x-sakhi-admin-token") token?: string) {
    return this.review.queue(token);
  }

  @Get("history")
  @ApiOkResponse({ description: "Returns persisted manual-review decision history." })
  history(@Headers("x-sakhi-admin-token") token?: string) {
    return this.review.history(token);
  }

  @Post("submissions/:submissionId/decision")
  @ApiOkResponse({ description: "Records a decision for a pending manual-review submission." })
  decide(
    @Headers("x-sakhi-admin-token") token: string | undefined,
    @Param("submissionId", new ParseUUIDPipe({ version: "4" })) submissionId: string,
    @Body() dto: ManualEligibilityDecisionDto,
  ) {
    return this.review.decide(submissionId, dto, token);
  }
}
