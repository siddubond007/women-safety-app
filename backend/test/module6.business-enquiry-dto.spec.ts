import { BadRequestException } from "@nestjs/common";
import { describe, expect, it } from "vitest";
import { CreateBusinessEnquiryDto } from "../src/module2/module2.dto.js";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";

describe("Module 6 business enquiry request validation", () => {
  const pipe = createGlobalValidationPipe();
  const metadata = {
    type: "body" as const,
    metatype: CreateBusinessEnquiryDto,
    data: "",
  };

  it.each(["In-App Chat", "WhatsApp", "Phone Call"])(
    "accepts the Flutter enquiry payload when preferred contact is %s",
    async (preferredContactMethod) => {
      const payload = {
        subjectOrProduct: "Handmade gifts",
        message: "Please share the available options.",
        preferredContactMethod,
        customerPhoneOrWhatsapp: "+91 9876543210",
      };
      const result = await pipe.transform(payload, metadata);
      expect(result).toMatchObject(payload);
    },
  );

  it("rejects unsupported preferred contact methods", async () => {
    await expect(
      pipe.transform(
        {
          message: "Please contact me.",
          preferredContactMethod: "Carrier pigeon",
        },
        metadata,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("rejects a contact number exceeding the configured limit", async () => {
    await expect(
      pipe.transform(
        {
          message: "Please contact me.",
          customerPhoneOrWhatsapp: "1".repeat(33),
        },
        metadata,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
