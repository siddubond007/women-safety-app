import { Catch, HttpException, HttpStatus, Injectable } from "@nestjs/common";
import type { ArgumentsHost, ExceptionFilter } from "@nestjs/common";
import type { Request, Response } from "express";
import { InjectPinoLogger, PinoLogger } from "nestjs-pino";

type RequestWithId = Request;

interface SafeExceptionDiagnostics {
  errorCode?: string;
  prismaModel?: string;
  prismaTarget?: string[];
}

function safeExceptionDiagnostics(exception: unknown): SafeExceptionDiagnostics {
  if (typeof exception !== "object" || exception === null) return {};

  const record = exception as Record<string, unknown>;
  const result: SafeExceptionDiagnostics = {};

  // Log only stable error identifiers and schema metadata. Never log the raw
  // exception message, query, parameters, connection string, or request body.
  if (typeof record.code === "string" && /^[A-Z][0-9]{4}$/.test(record.code)) {
    result.errorCode = record.code;
  }

  const meta = record.meta;
  if (typeof meta === "object" && meta !== null) {
    const metaRecord = meta as Record<string, unknown>;
    if (
      typeof metaRecord.modelName === "string" &&
      /^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(metaRecord.modelName)
    ) {
      result.prismaModel = metaRecord.modelName;
    }
    const target = metaRecord.target;
    if (
      Array.isArray(target) &&
      target.length <= 16 &&
      target.every(
        (item): item is string =>
          typeof item === "string" && /^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(item),
      )
    ) {
      result.prismaTarget = target;
    } else if (
      typeof target === "string" &&
      /^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(target)
    ) {
      result.prismaTarget = [target];
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
