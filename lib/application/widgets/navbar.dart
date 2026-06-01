import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/ai_usage_controller.dart';
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/pages/auth/logout_dialog.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/pages/auth/auth_page.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';

/// Shell navigation chrome: responsive desktop / tablet / mobile layouts.
class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onMenuTap,
    required this.onSearchTap,
    this.onLogoTap,
  });

  static const Color _ink = Color(0xFF111827);
  static const Color _searchFill = Color(0xFFF3F4F6);
  static const Color _mutedIcon = Color(0xFF9CA3AF);

  static const double _horizontalInset = 20;

  final int currentIndex;
  final ValueChanged<int> onMenuTap;
  final VoidCallback onSearchTap;

  /// When provided, the Stocbuy brand mark becomes tappable and invokes
  /// this callback. Used to "go home" from sub-pages like Stock Details.
  final VoidCallback? onLogoTap;

  static const _menus = <_TopMenuItem>[
    _TopMenuItem('Dashboard', Icons.grid_view_rounded),
    _TopMenuItem(
      'Stocbuy AI',
      Icons.auto_awesome_rounded,
      showLeadingIcon: true,
      accentWhenUnselected: true,
    ),
    _TopMenuItem('IPOs', Icons.trending_up_rounded),
    _TopMenuItem('Pricing', Icons.workspace_premium_outlined),
    _TopMenuItem('Watchlist', Icons.star_border_rounded, showLeadingIcon: true),
  ];

  @override
  Size get preferredSize {
    // Single height works for all breakpoints; status bar is applied in [HomePage].
    return const Size.fromHeight(68);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(
              color: AppColors.lightWhite.withValues(alpha: 0.9),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkblue.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalInset,
            vertical: 8,
          ),
          child: ResponsiveBuilder(
            mobile: (ctx) => _MobileNavChrome(
              onSearchTap: onSearchTap,
              onMenuTap: () => Scaffold.of(ctx).openDrawer(),
              onLogoTap: onLogoTap,
            ),
            tablet: (ctx) => _TabletNavChrome(
              onSearchTap: onSearchTap,
              onMenuTap: () => Scaffold.of(ctx).openDrawer(),
              onLogoTap: onLogoTap,
            ),
            desktop: (_) => _DesktopNavChrome(
              menus: _menus,
              currentIndex: currentIndex,
              onMenuTap: onMenuTap,
              onSearchTap: onSearchTap,
              onLogoTap: onLogoTap,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Desktop ────────────────────────────────────────────────────────────────

class _DesktopNavChrome extends StatelessWidget {
  const _DesktopNavChrome({
    required this.menus,
    required this.currentIndex,
    required this.onMenuTap,
    required this.onSearchTap,
    this.onLogoTap,
  });

  final List<_TopMenuItem> menus;
  final int currentIndex;
  final ValueChanged<int> onMenuTap;
  final VoidCallback onSearchTap;
  final VoidCallback? onLogoTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = Get.find<AuthController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final barW = constraints.maxWidth;
        // Search sits beside brand; cap width so nav + auth keep enough room.
        final searchW = math.min(280.0, math.max(168.0, barW * 0.19));

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TappableBrand(
              onTap: onLogoTap,
              child: const StocbuyBrandMark(
                labelColor: AppNavBar._ink,
                logoSize: 26,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: searchW,
              child: NavSearchField(
                hintText: 'Search Stocks, IPOs, etc...',
                onTap: onSearchTap,
              ),
            ),
            // Single Expanded — do not pair Spacer + Flexible (both flex:1 splits space 50/50
            // and squeezes the menu/auth strip, clipping buttons on the right).
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  return ClipRect(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < menus.length; i++) ...[
                              if (i > 0) const SizedBox(width: 4),
                              DesktopNavLink(
                                label: menus[i].label,
                                leadingIcon: menus[i].showLeadingIcon
                                    ? menus[i].icon
                                    : null,
                                isSelected: currentIndex == i,
                                accentWhenUnselected:
                                    menus[i].accentWhenUnselected,
                                onTap: () => onMenuTap(i),
                              ),
                            ],
                            const SizedBox(width: 12),
                            Obx(() {
                              if (!auth.isLoggedIn.value) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _LogInButton(
                                      onPressed: () => showAuthDialog(
                                        context,
                                        initialTab: AuthTab.login,
                                      ),
                                      textStyle: textTheme.titleSmall,
                                    ),
                                    const SizedBox(width: 10),
                                    _SignUpButton(
                                      onPressed: () => showAuthDialog(
                                        context,
                                        initialTab: AuthTab.signup,
                                      ),
                                      textStyle: textTheme.titleSmall,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _AiUsagePill(onTap: () {}, compact: false),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => showLogoutDialog(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.red,
                                      textStyle: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text('Logout'),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class DesktopNavLink extends StatefulWidget {
  const DesktopNavLink({
    super.key,
    required this.label,
    this.leadingIcon,
    required this.isSelected,
    required this.accentWhenUnselected,
    required this.onTap,
  });

  final String label;
  final IconData? leadingIcon;
  final bool isSelected;
  final bool accentWhenUnselected;
  final VoidCallback onTap;

  @override
  State<DesktopNavLink> createState() => _DesktopNavLinkState();
}

class _DesktopNavLinkState extends State<DesktopNavLink> {
  bool _hover = false;

  Color get _labelColor {
    if (widget.isSelected || widget.accentWhenUnselected) {
      return AppColors.lightblue;
    }
    if (_hover) {
      return AppNavBar._ink.withValues(alpha: 0.82);
    }
    return AppNavBar._ink;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.surfaceMuted.withValues(alpha: 0.75),
          splashColor: AppColors.lightblue.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: widget.isSelected ? 2.5 : 0,
                  color: widget.isSelected
                      ? AppColors.lightblue
                      : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.leadingIcon != null) ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _hover ? 1 : 0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) {
                      return Transform.translate(
                        offset: Offset(0, -1.5 * t),
                        child: child,
                      );
                    },
                    child: Icon(
                      widget.leadingIcon,
                      size: 16,
                      color: _labelColor,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _labelColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: -0.12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavSearchField extends StatelessWidget {
  const NavSearchField({
    super.key,
    required this.hintText,
    required this.onTap,
  });

  final String hintText;
  final VoidCallback onTap;

  static const double _fieldHeight = 36;

  @override
  Widget build(BuildContext context) {
    final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppNavBar._mutedIcon,
      fontWeight: FontWeight.w500,
      fontSize: 13,
    );

    return Semantics(
      button: true,
      label: 'Search. $hintText',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          hoverColor: AppNavBar._searchFill.withValues(alpha: 0.88),
          splashColor: AppColors.lightblue.withValues(alpha: 0.06),
          child: Ink(
            height: _fieldHeight,
            decoration: BoxDecoration(
              color: AppNavBar._searchFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppNavBar._mutedIcon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hintText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hintStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Text(
                        '/',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color.fromARGB(103, 88, 102, 126),
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogInButton extends StatefulWidget {
  const _LogInButton({required this.onPressed, required this.textStyle});

  final VoidCallback onPressed;
  final TextStyle? textStyle;

  @override
  State<_LogInButton> createState() => _LogInButtonState();
}

class _LogInButtonState extends State<_LogInButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _hover ? AppColors.border : AppColors.lightWhite,
            width: 1.2,
          ),
          color: _hover ? AppColors.surfaceMuted : Colors.transparent,
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: AppColors.darkblue.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(999),
            hoverColor: Colors.transparent,
            splashColor: AppColors.lightblue.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Log In',
                style: widget.textStyle?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppNavBar._ink,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignUpButton extends StatefulWidget {
  const _SignUpButton({required this.onPressed, required this.textStyle});

  final VoidCallback onPressed;
  final TextStyle? textStyle;

  @override
  State<_SignUpButton> createState() => _SignUpButtonState();
}

class _SignUpButtonState extends State<_SignUpButton> {
  bool _hover = false;

  static const _topBlue = Color(0xFF5B7CFF);
  static const _bottomBlue = Color(0xFF2F4FD6);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _hover
                ? const [Color(0xFF6C8BFF), Color(0xFF355AE8)]
                : const [_topBlue, _bottomBlue],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: _hover ? 0.34 : 0.22),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(999),
            hoverColor: Colors.transparent,
            splashColor: Colors.white.withValues(alpha: 0.18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Sign Up',
                style: widget.textStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 13,
                  letterSpacing: 0.15,
                  height: 1.1,
                  shadows: const [
                    Shadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 0.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiUsagePill extends StatelessWidget {
  const _AiUsagePill({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AiUsageController>();
    return Obx(() {
      final usage = controller.usage.value;
      final loading = controller.isLoading.value;
      final error = controller.errorMessage.value;
      final label = loading
          ? 'Loading...'
          : usage != null
          ? usage.isUnlimited
                ? 'Unlimited AI'
                : '${usage.used} / ${usage.limit}'
          : 'Usage unavailable';
      final details =
          usage?.message ?? (error.isNotEmpty ? error : 'AI usage status');

      return Tooltip(
        message: details,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            hoverColor: AppColors.surfaceMuted.withValues(alpha: 0.6),
            splashColor: AppColors.lightblue.withValues(alpha: 0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: AppColors.lightblue,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppNavBar._ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if (usage != null)
                        Text(
                          usage.plan.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppNavBar._mutedIcon,
                                fontSize: 10,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ── Tablet compact chrome ─────────────────────────────────────────────────

class _TabletNavChrome extends StatelessWidget {
  const _TabletNavChrome({
    required this.onSearchTap,
    required this.onMenuTap,
    this.onLogoTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final VoidCallback? onLogoTap;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return SizedBox(
      height: 50,
      child: Obx(() {
        return Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TappableBrand(
                  onTap: onLogoTap,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: StocbuyBrandMark(
                      compact: false,
                      logoSize: 24,
                      labelColor: AppNavBar._ink,
                    ),
                  ),
                ),
              ),
            ),
            _ChromeIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              size: 44,
              iconSize: 24,
              onPressed: onSearchTap,
            ),
            if (auth.isLoggedIn.value) ...[
              const SizedBox(width: 6),
              _AiUsagePill(onTap: () {}, compact: true),
            ],
            const SizedBox(width: 6),
            _ChromeIconButton(
              icon: Icons.menu_rounded,
              tooltip: 'Menu',
              size: 44,
              iconSize: 24,
              onPressed: onMenuTap,
            ),
          ],
        );
      }),
    );
  }
}

// ── Mobile compact chrome ──────────────────────────────────────────────────

class _MobileNavChrome extends StatelessWidget {
  const _MobileNavChrome({
    required this.onSearchTap,
    required this.onMenuTap,
    this.onLogoTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final VoidCallback? onLogoTap;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return SizedBox(
      height: 46,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 280;
          final iconBox = narrow ? 40.0 : 42.0;
          final iconPx = narrow ? 22.0 : 23.0;

          return Obx(
            () => Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _TappableBrand(
                      onTap: onLogoTap,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: StocbuyBrandMark(
                          compact: true,
                          labelColor: AppNavBar._ink,
                        ),
                      ),
                    ),
                  ),
                ),
                _ChromeIconButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Search',
                  size: iconBox,
                  iconSize: iconPx,
                  onPressed: onSearchTap,
                ),
                if (auth.isLoggedIn.value) ...[
                  const SizedBox(width: 4),
                  _AiUsagePill(onTap: () {}, compact: true),
                ],
                const SizedBox(width: 2),
                _ChromeIconButton(
                  icon: Icons.menu_rounded,
                  tooltip: 'Menu',
                  size: iconBox,
                  iconSize: iconPx,
                  onPressed: onMenuTap,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChromeIconButton extends StatefulWidget {
  const _ChromeIconButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    required this.iconSize,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final String tooltip;

  @override
  State<_ChromeIconButton> createState() => _ChromeIconButtonState();
}

class _ChromeIconButtonState extends State<_ChromeIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.surfaceMuted,
          splashColor: AppColors.lightblue.withValues(alpha: 0.12),
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: AppColors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopMenuItem {
  const _TopMenuItem(
    this.label,
    this.icon, {
    this.showLeadingIcon = false,
    this.accentWhenUnselected = false,
  });

  final String label;
  final IconData icon;
  final bool showLeadingIcon;
  final bool accentWhenUnselected;
}

/// Wraps the Stocbuy brand mark with an [InkWell] when [onTap] is provided
/// (so sub-pages like Stock Details can "go home"). Falls back to the bare
/// child for the homepage (default) where tapping the logo is a no-op.
class _TappableBrand extends StatelessWidget {
  const _TappableBrand({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.surfaceMuted.withValues(alpha: 0.4),
        splashColor: AppColors.lightblue.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: child,
        ),
      ),
    );
  }
}
