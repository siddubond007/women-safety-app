-- Adds an explicit rejected eligibility-review outcome.
-- This migration is prepared for review only; do not apply it until explicitly authorized.
ALTER TYPE "verification_status" ADD VALUE IF NOT EXISTS 'REJECTED';