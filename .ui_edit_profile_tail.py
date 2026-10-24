from pathlib import Path
p=Path(r"D:\Development\Projects\women_safety_app\app\lib\features\profile\screens\edit_profile_screen.dart")
s=p.read_text(encoding="utf-8")
old=r"RegExp(r'^[^\\\\s@]+@[^\\\\s@]+\\\\.[^\\\\s@]{2,}$')"
# Keep the Dart raw-regex escape sequence single.
new=r"RegExp(r'^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$')"
if old not in s:
    old=r"RegExp(r'^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$')"
if old not in s: print("note: email regex exact variant not found; leaving for formatter/analyzer")
else: s=s.replace(old,new,1)
marker="""                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddInterestDialog()"""
replacement="""                ),
                const SizedBox(height: 16),
                Material(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  child: SwitchListTile(
                    value: _businessProfileEnabled,
                    onChanged: (enabled) async {
                      final existingUrl = SakhiPrototypeState
                          .instance.currentUser.businessProfileUrl;
                      if (enabled && (existingUrl == null || existingUrl.isEmpty)) {
                        await showModalBottomSheet<void>(
                          context: context,
                          backgroundColor: AppColors.cardSurface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          builder: (sheetContext) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Business page not linked yet',
                                    style: AppTypography.sectionTitle,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'This setting can be enabled after an eligible Women-Owned Business page is linked to your Sakhi account. Marketplace setup is not available in this module.',
                                    style: AppTypography.bodyRegular,
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(sheetContext),
                                      child: const Text('Got it'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() => _businessProfileEnabled = enabled);
                    },
                    activeColor: AppColors.primaryPurple,
                    title: const Text(
                      'Link my Women-Owned Business Page',
                      style: AppTypography.bodyMedium,
                    ),
                    subtitle: const Text(
                      'Show an eligible linked business page on your profile.',
                      style: AppTypography.subtitle,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: SakhiPillButton(
                    label: 'Save Profile Changes',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddInterestDialog()"""
if s.count(marker)!=1:
    raise SystemExit(f"end-profile insertion marker count {s.count(marker)}")
s=s.replace(marker,replacement,1)
p.write_text(s,encoding="utf-8",newline="")
print("Added optional business-link status and bottom Save Profile Changes CTA")
