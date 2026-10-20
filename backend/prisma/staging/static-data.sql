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

COMMIT;
