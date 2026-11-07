import { Controller, Get } from "@nestjs/common";
import {
  ApiOkResponse,
  ApiServiceUnavailableResponse,
  ApiTags,
} from "@nestjs/swagger";
import { HealthService } from "./health.service.js";

@ApiTags("health")
@Controller("health")
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get("live")
  @ApiOkResponse({ description: "The API process is running." })
  live(): { status: "ok" } {
    return this.healthService.live();
  }

  @Get("ready")
  @ApiOkResponse({
    description: "The API and its PostgreSQL dependency are ready.",
  })
  @ApiServiceUnavailableResponse({
    description:
      "The database check failed. No infrastructure details are returned.",
  })
  ready(): ReturnType<HealthService["ready"]> {
    return this.healthService.ready();
  }
}
