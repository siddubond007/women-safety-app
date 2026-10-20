# Sakhi Module 3 — Generated Asset Inventory

## 1. Visual Generation Methodology & Transparency Note

All 12 default women's avatars and 4 Module 3 editorial feed illustrations were generated using our deterministic high-resolution supersampled vector/raster illustration pipeline (`generate_module3_assets.py` -> `1024x1024` supersampled RGBA downscaled with Lanczos anti-aliasing to `512x512` WebP for avatars and `1200x750` WebP for editorial scenes) and bundled directly inside `app/assets/images/` so they work 100% offline with zero external URL dependencies.

Each of the 12 default women's avatars is visually distinct in **facial shape, skin tone, hairstyle, outfit style, jewelry, eyewear, and color palette**, and is strictly treated as a default fictional avatar (never misrepresented as a member's uploaded photo).

## 2. Default Women Avatars (`app/assets/images/profile/`)

| Filename | Format | Dimensions | Distinct Visual Characteristics | Intended Reuse |
| ----- | ----- | ----- | ----- | ----- |
| `avatar_siddhu.webp` | WebP (RGBA) | `512x512` | Warm medium skin tone, heart face, layered crown hair, orchid shawl wrap, bindi, gold studs | Default avatar for `Siddhu` & deterministic fallback `#0` |
| `avatar_ananya.webp` | WebP (RGBA) | `512x512` | Light-medium warm skin, oval face, side-part waves, rose blazer, round plum glasses, bindi | Default avatar for `Ananya Sharma` & fallback `#1` |
| `avatar_meera.webp` | WebP (RGBA) | `512x512` | Rich medium-deep skin, heart face, high bun with jasmine garland, emerald saree with gold zari border, jhumka earrings | Default avatar for `Meera Nair` & fallback `#2` |
| `avatar_kavya.webp` | WebP (RGBA) | `512x512` | Warm peach-tan skin, round face, modern short bob, terracotta boat-neck top, gold hoop earrings | Default avatar for `Kavya Reddy` & fallback `#3` |
| `avatar_ishita.webp` | WebP (RGBA) | `512x512` | Medium golden-brown skin, soft-square face, voluminous curly cloud hair, violet turtleneck, cat-eye glasses, pearl drops | Default avatar for `Ishita Roy` & fallback `#4` |
| `avatar_priya.webp` | WebP (RGBA) | `512x512` | Deep warm bronze skin, oval face, cascading side braid with gold tie, cerulean embroidered kurta, chandbali earrings | Default avatar for `Priya Verma` & fallback `#5` |
| `avatar_sneha.webp` | WebP (RGBA) | `512x512` | Rich deep brown skin, oval face, long center-part waves, mulberry saree drape, gold jhumkas | Default avatar for `Sneha Kulkarni` & fallback `#6` |
| `avatar_riya.webp` | WebP (RGBA) | `512x512` | Warm light-tan skin, round face, high volume ponytail, coral blazer, gold hoops | Default avatar for `Riya Kapoor` & fallback `#7` |
| `avatar_divya.webp` | WebP (RGBA) | `512x512` | Medium bronze skin, heart face, low chignon with blush flowers, sage embroidered kurta, round glasses, pearl drops | Default avatar for `Divya Menon` & fallback `#8` |
| `avatar_zoya.webp` | WebP (RGBA) | `512x512` | Warm olive-tan skin, oval face, plum dupatta headscarf with gold border, chandbali earrings | Default avatar for `Zoya Khan` & fallback `#9` |
| `avatar_lakshmi.webp` | WebP (RGBA) | `512x512` | Deep warm brown skin, soft-square face, jasmine bun, crimson & gold zari saree, red bindi, gold jhumkas | Default avatar for `Lakshmi` & fallback `#10` |
| `avatar_nisha.webp` | WebP (RGBA) | `512x512` | Medium warm tan skin, heart face, short pixie wave, indigo turtleneck, cat-eye glasses, gold studs | Default avatar for `Nisha` & fallback `#11` |

## 3. Module 3 Editorial Feed Illustrations (`app/assets/images/community/`)

| Filename | Format | Dimensions | Visual Scene Description | Intended Reuse |
| ----- | ----- | ----- | ----- | ----- |
| `community_circle_gathering.webp` | WebP | `1200x750` | Sunlit courtyard arches with three women in a supportive circle | `Community` category default & composer editorial artwork |
| `business_artisan_studio.webp` | WebP | `1200x750` | Women-led craft studio with terracotta pottery, textiles, and warm pendant lamps | `Business Updates` category showcase artwork |
| `safety_night_commute_guide.webp` | WebP | `1200x750` | Illuminated evening walkway with streetlamps and central safety shield emblem | `Safety Awareness` category guide artwork |
| `wellness_morning_journal.webp` | WebP | `1200x750` | Calm sage-green morning ritual with open mindfulness journal and sunrise | `Wellness and Lifestyle` category artwork |
