import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from "@nestjs/common";
import type { Request } from "express";
import { AuthenticationService } from "../auth/auth.service.js";

/** Set only after a backend session and eligibility status have been checked. */
export interface EligibilityAuthenticatedRequest extends Request {
  sakhiAccountId?: string;
}

/**
 * Apply to every protected community controller/route when those routes are
 * implemented. A client-side flag is never authorization.
 */
@Injectable()
export class VerifiedEligibilityGuard implements CanActivate {
  constructor(private readonly auth: AuthenticationService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<EligibilityAuthenticatedRequest>();
    const authorization = request.headers.authorization;
    const session = await this.auth.authenticateAuthorization(authorization);

    if (session.account.eligibilityStatus !== "VERIFIED") {
      throw new ForbiddenException({
        statusCode: 403,
        code: "eligibility_required",
        message:
          "Verified eligibility is required to access this protected community feature.",
        eligibilityStatus: session.account.eligibilityStatus,
      });
    }

    request.sakhiAccountId = session.accountId;
    return true;
  }
}
