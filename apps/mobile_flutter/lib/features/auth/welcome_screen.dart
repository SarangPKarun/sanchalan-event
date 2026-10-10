import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/bottom_action_bar.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/primary_button.dart';

/// First screen for a signed-out user.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onGetStarted, this.onDebugPreviews});

  final VoidCallback onGetStarted;

  /// Debug builds only: opens the design previews.
  final VoidCallback? onDebugPreviews;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          // Soft decorative circles, purely visual.
          const Positioned(
            top: -90,
            right: -70,
            child: _Blob(size: 260, color: AppColors.primaryContainer),
          ),
          const Positioned(
            top: 120,
            left: -110,
            child: _Blob(size: 200, color: AppColors.goldContainer),
          ),
          const Positioned(
            bottom: 120,
            right: -90,
            child: _Blob(size: 220, color: AppColors.maroonContainer),
          ),
          if (onDebugPreviews != null)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: TextButton(onPressed: onDebugPreviews, child: const Text('Previews')),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.xl,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpace.xl),
                              const Center(
                                child: BrandMark(size: 88, wordmark: true),
                              ),
                              const SizedBox(height: AppSpace.xl),
                              Semantics(
                                header: true,
                                child: Text(
                                  'Plan every celebration, stress-free',
                                  textAlign: TextAlign.center,
                                  style: text.headlineMedium?.copyWith(
                                    color: AppColors.maroon,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpace.m),
                              Text(
                                'A step-by-step plan, your budget and trusted vendors, all in one place.',
                                textAlign: TextAlign.center,
                                style: text.bodyLarge?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: AppSpace.xl),
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _Feature(
                                      icon: Icons.checklist_rounded,
                                      label: 'Smart roadmap',
                                    ),
                                  ),
                                  Expanded(
                                    child: _Feature(
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      label: 'Budget tracker',
                                    ),
                                  ),
                                  Expanded(
                                    child: _Feature(
                                      icon: Icons.storefront_outlined,
                                      label: 'Trusted vendors',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpace.xl),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                BottomActionBar(
                  children: [
                    PrimaryButton(
                      label: 'Get started',
                      icon: Icons.arrow_forward,
                      onPressed: onGetStarted,
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text(
                      'For families, planners and vendors',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.7),
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outline),
            boxShadow: AppShadows.soft,
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpace.s),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.ink),
        ),
      ],
    );
  }
}
