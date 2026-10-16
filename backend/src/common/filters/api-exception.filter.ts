import { Catch, HttpException, HttpStatus, Injectable } from "@nestjs/common";
import type { ArgumentsHost, ExceptionFilter } from "@nestjs/common";
import type { Request, Response } from "express";
import { InjectPinoLogger, PinoLogger } from "nestjs-pino";

type RequestWithId = Request;

interface SafeExceptionDiagnostics {
  errorCode?: string;
  prismaModel?: string;
  prismaTarget?: string[];
  driverErrorCode?: string;
  driverErrorKind?: string;
  driverSeverity?: string;
  driverSchema?: string;
  driverTable?: string;
  driverColumn?: string;
  driverConstraint?: string;
}

function safeExceptionDiagnostics(exception: unknown): SafeExceptionDiagnostics {
  if (typeof exception !== "object" || exception === null) return {};

  const record = exception as Record<string, unknown>;
  const result: SafeExceptionDiagnostics = {};
  const safeIdentifier = (value: unknown): string | undefined =>
    typeof value === "string" &&
    /^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(value)
      ? value
      : undefined;

  // Log only stable error identifiers and schema metadata. Never log the raw
  // exception message, query, parameters, connection string, or request body.
  if (typeof record.code === "string" && /^[A-Z][0-9]{4}$/.test(record.code)) {
    result.errorCode = record.code;
  }

  const meta = record.meta;
  if (typeof meta === "object" && meta !== null) {
    const metaRecord = meta as Record<string, unknown>;
    result.prismaModel = safeIdentifier(metaRecord.modelName);
    const target = metaRecord.target;
    if (
      Array.isArray(target) &&
      target.length <= 16 &&
      target.every((item) => safeIdentifier(item) !== undefined)
    ) {
      result.prismaTarget = target as string[];
    } else if (safeIdentifier(target)) {
      result.prismaTarget = [target as string];
    }

    // Prisma 7 driver-adapter errors can wrap the original PostgreSQL error
    // under meta.driverAdapterError.cause. Extract only SQLSTATE and
    // allow-listed identifiers; do not log driver messages or SQL details.
    const adapterError = metaRecord.driverAdapterError;
    if (typeof adapterError === "object" && adapterError !== null) {
      const cause = (adapterError as Record<string, unknown>).cause;
      if (typeof cause === "object" && cause !== null) {
        const driver = cause as Record<string, unknown>;
        const code = driver.originalCode ?? driver.code ?? driver.sqlState;
        if (typeof code === "string" && /^[0-9A-Z]{5}$/.test(code)) {
          result.driverErrorCode = code;
        }
        result.driverErrorKind = safeIdentifier(driver.kind);
        result.driverSeverity = safeIdentifier(driver.severity);
        result.driverSchema = safeIdentifier(driver.schema);
        result.driverTable = safeIdentifier(driver.table);
        result.driverColumn = safeIdentifier(driver.column);
        const constraint = driver.constraint;
        if (typeof constraint === "string") {
          result.driverConstraint = safeIdentifier(constraint);
        } else if (typeof constraint === "object" && constraint !== null) {
          const constraintRecord = constraint as Record<string, unknown>;
          result.driverConstraint =
            safeIdentifier(constraintRecord.name) ??
            safeIdentifier(constraintRecord.index);
        }
      }
    }
  }

  return result;
}

@Catch()
@Injectable()
export class ApiExceptionFilter implements ExceptionFilter {
  constructor(
    @InjectPinoLogger(ApiExceptionFilter.name)
    private readonly logger: PinoLogger,
  ) {
    this.logger.setContext(ApiExceptionFilter.name);
  }

  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<RequestWithId>();
    const statusCode =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;
    const requestId = request.id ?? null;

    let message: string;
    let details: unknown;
    if (statusCode >= 500) {
      message =
        statusCode === HttpStatus.SERVICE_UNAVAILABLE
          ? "Service temporarily unavailable"
          : "An unexpected error occurred";
    } else if (exception instanceof HttpException) {
      const body = exception.getResponse();
      if (typeof body === "string") {
        message = body;
      } else if (typeof body === "object" && body !== null) {
        const record = body as Record<string, unknown>;
        message =
          typeof record.message === "string"
            ? record.message
            : "Request failed";
        details = record.details;
      } else {
        message = "Request failed";
      }
    } else {
      message = "An unexpected error occurred";
    }

    if (statusCode >= 500) {
      this.logger.error(
        {
          requestId,
          statusCode,
          exceptionType:
            exception instanceof Error ? exception.name : "UnknownException",
          ...safeExceptionDiagnostics(exception),
        },
        "Request failed",
      );
    }

    response.status(statusCode).json({
      statusCode,
      error: this.publicErrorName(statusCode),
      message,
      ...(details === undefined ? {} : { details }),
      requestId,
    });
  }

  private publicErrorName(statusCode: number): string {
    if (statusCode === HttpStatus.SERVICE_UNAVAILABLE) {
      return "Service Unavailable";
    }
    if (statusCode >= 500) {
      return "Internal Server Error";
    }
    if (statusCode === HttpStatus.BAD_REQUEST) {
      return "Bad Request";
    }
    if (statusCode === HttpStatus.NOT_FOUND) {
      return "Not Found";
    }
    if (statusCode === HttpStatus.UNAUTHORIZED) {
      return "Unauthorized";
    }
    if (statusCode === HttpStatus.FORBIDDEN) {
      return "Forbidden";
    }
    return "Request Error";
  }
}
