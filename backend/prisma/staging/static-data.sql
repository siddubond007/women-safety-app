-- Staging-only non-personal configuration metadata.
-- Intentionally does not create fictional member accounts, profiles, or posts.
BEGIN;

INSERT INTO public.policy_document_versions
  (id, document_type, version, status, created_at)
VALUES
  (gen_random_uuid(), 'TERMS', 'friend-testing-draft-v1', 'DRAFT', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'PRIVACY', 'friend-testing-draft-v1', 'DRAFT', CURRENT_TIMESTAMP)
ON CONFLICT (document_type, version) DO NOTHING;

INSERT INTO public.feed_category_configs
  (slug, name, description, icon_key, accent_color_hex, is_enabled, display_order, updated_by)
VALUES
  ('following', 'Following', 'Updates from members and circles you follow.', 'heart_handshake', '#EC4899', TRUE, 1, 'staging-static-config'),
  ('community', 'Community', 'Discussions, peer encouragement, and shared experiences.', 'users', '#A855F7', TRUE, 2, 'staging-static-config'),
  ('trending', 'Trending', 'High-engagement conversations and timely topics.', 'flame', '#F59E0B', TRUE, 3, 'staging-static-config'),
  ('business_updates', 'Business Updates', 'Showcases and announcements from women-led businesses.', 'briefcase', '#8B5CF6', TRUE, 4, 'staging-static-config'),
  ('safety_awareness', 'Safety Awareness', 'Safety advisories and awareness content.', 'shield_check', '#10B981', TRUE, 5, 'staging-static-config'),
  ('wellness_lifestyle', 'Wellness and Lifestyle', 'Mindfulness, journaling, and lifestyle content.', 'sparkles', '#14B8A6', TRUE, 6, 'staging-static-config')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.platform_registration_policies
  (policy_key, minimum_age_years, updated_by, change_reason)
VALUES
  ('default', 18, 'staging-static-config', 'Initial staging registration minimum-age policy.')
ON CONFLICT (policy_key) DO NOTHING;


INSERT INTO public.safety_helpline_configs
  (code, number, title, subtitle, category, is_enabled, display_order, updated_by)
VALUES
  ('112', '112', '112 — India National Emergency Number', '24/7 Police, Fire & Medical Emergency Response (ERSS)', 'NATIONAL_EMERGENCY', TRUE, 1, 'staging-static-config'),
  ('100', '100', '100 — Direct Police Control Room', '24/7 Immediate Police Dispatch Across India', 'POLICE', TRUE, 2, 'staging-static-config'),
  ('1091', '1091', '1091 — Women in Distress Helpline', 'Police Women Safety Cell • Toll-Free', 'WOMEN_SAFETY', TRUE, 3, 'staging-static-config'),
  ('181', '181', '181 — Women Domestic & Safety Helpline', '24/7 Support & Counselling', 'WOMEN_SAFETY', TRUE, 4, 'staging-static-config'),
  ('108', '108', '108 / 1930 — Medical Ambulance (108) & Cyber Crime (1930)', 'Emergency medical & online fraud support', 'MEDICAL_CYBER', TRUE, 5, 'staging-static-config')
ON CONFLICT (code) DO NOTHING;

COMMIT;
