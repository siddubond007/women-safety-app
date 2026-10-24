from pathlib import Path
import re
root = Path(r"D:\Development\Projects\women_safety_app")
def replace_regex(rel, pattern, replacement, expected=1):
    p = root / rel
    s = p.read_text(encoding="utf-8")
    ns, n = re.subn(pattern, replacement, s, count=0, flags=re.S)
    if n != expected:
        raise SystemExit(f"{rel}: pattern expected {expected}, got {n}: {pattern[:100]}")
    p.write_text(ns, encoding="utf-8", newline="")
    print(f"patched {rel}: {n}")
def replace_once(rel, old, new):
    p = root / rel
    s = p.read_text(encoding="utf-8")
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"{rel}: exact text expected once, got {n}: {old[:90]!r}")
    p.write_text(s.replace(old, new, 1), encoding="utf-8", newline="")
    print(f"patched {rel}: exact replacement")
home = "app/lib/features/home/screens/home_screen.dart"
replace_once(home, "import '../../community/widgets/feed_post_card.dart';", "import '../../community/widgets/feed_post_card.dart';\nimport '../../explore/screens/explore_discovery_screens.dart';")
replace_once(home, "padding: const EdgeInsets.only(bottom: 28),", "padding: const EdgeInsets.only(bottom: 96),")
replace_regex(home, r"\n {22}if \(_searchQuery\.trim\(\)\.isNotEmpty\) \.\.\.\[.*?\n {22}\],\n {22}const SizedBox\(height: 16\),", "\n                      const SizedBox(height: 16),", 1)
replace_regex(home, r"\n {22}// Live PostgreSQL Sync Status Pill.*?\n {22}// Personalized Greeting Card", "\n                      // Personalized Greeting Card", 1)
replace_once(home, "                        controller: _searchController,\n                        onChanged:", "                        controller: _searchController,\n                        onTap: _openSearchResults,\n                        onChanged:")
replace_once(home, "  @override\n  Widget build(BuildContext context) {", "  void _openSearchResults() {\n    Navigator.of(context).push(\n      MaterialPageRoute<void>(\n        builder: (_) => SearchResultsScreen(\n          initialQuery: _searchController.text.trim(),\n        ),\n      ),\n    );\n  }\n\n  @override\n  Widget build(BuildContext context) {")
greet = "app/lib/features/home/widgets/greeting_banner_card.dart"
replace_once(greet, "                        Icons.verified_user_rounded,", "                        Icons.groups_rounded,")
replace_once(greet, "'VERIFIED SAFE SPACE',", "'YOUR SAKHI COMMUNITY',")
replace_regex(greet, r"            // Standalone reusable botanical flower accents.*?\n            // Left-side crisp greeting content", """            // The complete illustration is clipped to the right-side artwork
            // region so decorative petals can never cross into the greeting.
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 150,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      right: -12,
                      bottom: -10,
                      child: SakhiBotanicalFlower(
                        type: SakhiFlowerType.poppyBlush,
                        width: 86,
                        height: 108,
                        opacity: 0.72,
                        flipHorizontal: true,
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: SakhiCrispHeroArt(
                        variant: 'greeting',
                        width: 144,
                        height: 168,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Left-side crisp greeting content""", 1)
print("stage-one layout repairs done")
