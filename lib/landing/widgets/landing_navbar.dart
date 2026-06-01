import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';

import '../landing_navigation.dart';

const landingMenuItems = [
  'How it works',
  'Features',
  'Pricing',
  'FAQ',
];

class LandingNavbar extends StatelessWidget {
  const LandingNavbar({
    required this.selectedIndex,
    required this.onMenuSelected,
    super.key,
  });

  final int? selectedIndex;
  final ValueChanged<int> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 960;
        final isTiny = constraints.maxWidth < 220;

        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 1180),
            padding: EdgeInsets.symmetric(
              horizontal: isTiny ? 8 : (isCompact ? 10 : 18),
              vertical: isCompact ? 8 : 9,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: .08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: isCompact
                ? _CompactNavbar(
                    onMenuPressed: Scaffold.of(context).openEndDrawer,
                  )
                : _DesktopNavbar(
                    selectedIndex: selectedIndex,
                    onMenuSelected: onMenuSelected,
                  ),
          ),
        );
      },
    );
  }
}

class LandingDrawer extends StatelessWidget {
  const LandingDrawer({
    required this.selectedIndex,
    required this.onMenuSelected,
    super.key,
  });

  final int? selectedIndex;
  final ValueChanged<int> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth < 360 ? screenWidth : 320.0;
    final horizontalPadding = drawerWidth < 220 ? 10.0 : 20.0;

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(width: drawerWidth - (horizontalPadding * 2)),
              const SizedBox(height: 26),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (
                      var index = 0;
                      index < landingMenuItems.length;
                      index++
                    )
                      _DrawerMenuItem(
                        label: landingMenuItems[index],
                        isSelected: selectedIndex == index,
                        onTap: () {
                          Navigator.of(context).maybePop();
                          onMenuSelected(index);
                        },
                      ),
                  ],
                ),
              ),
              const _TryAiButton(isExpanded: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavbar extends StatelessWidget {
  const _DesktopNavbar({
    required this.selectedIndex,
    required this.onMenuSelected,
  });

  final int? selectedIndex;
  final ValueChanged<int> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const StocbuyBrandMark(),
        const SizedBox(width: 26),
        for (var index = 0; index < landingMenuItems.length; index++)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: _NavMenuItem(
              label: landingMenuItems[index],
              isSelected: selectedIndex == index,
              onTap: () => onMenuSelected(index),
            ),
          ),
        const SizedBox(width: 18),
        const Spacer(),
        const _LoginButton(),
        const SizedBox(width: 10),
        const _TryAiButton(),
      ],
    );
  }
}

class _CompactNavbar extends StatelessWidget {
  const _CompactNavbar({required this.onMenuPressed});

  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLogin = constraints.maxWidth >= 280;
        final showBrandText = constraints.maxWidth >= 190;
        final isVeryNarrow = constraints.maxWidth < 240;

        return Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: showBrandText
                    ? StocbuyBrandMark(compact: isVeryNarrow)
                    : StocbuyLogoMark(size: isVeryNarrow ? 18 : 20),
              ),
            ),
            const SizedBox(width: 8),
            if (showLogin) ...[
              _LoginButton(isCompact: isVeryNarrow),
              SizedBox(width: isVeryNarrow ? 2 : 6),
            ],
            SizedBox.square(
              dimension: isVeryNarrow ? 36 : 40,
              child: IconButton(
                onPressed: onMenuPressed,
                icon: const Icon(Icons.menu_rounded),
                iconSize: isVeryNarrow ? 21 : 24,
                padding: EdgeInsets.zero,
                color: const Color(0xFF111827),
                tooltip: 'Open menu',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NavMenuItem extends StatefulWidget {
  const _NavMenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavMenuItem> createState() => _NavMenuItemState();
}

class _NavMenuItemState extends State<_NavMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _isHovered && !widget.isSelected
                ? const Color(0xFF0F172A).withValues(alpha: .05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? const Color(0xFF111827)
                      : const Color(0xFF475569),
                  fontSize: 13,
                  height: 1,
                  fontWeight: widget.isSelected
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
              Positioned(
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: widget.isSelected ? 28 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final showLabel = width >= 150;

    return Row(
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: showLabel
                ? StocbuyBrandMark(compact: width < 210)
                : const StocbuyLogoMark(size: 20),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox.square(
          dimension: 36,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
            iconSize: 20,
            padding: EdgeInsets.zero,
            color: const Color(0xFF111827),
            tooltip: 'Close menu',
          ),
        ),
      ],
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  const _DrawerMenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 96;
        final horizontalPadding = constraints.maxWidth < 150 ? 8.0 : 12.0;
        final showIndicator = isSelected && constraints.maxWidth >= 96;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isVeryNarrow ? 12 : 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: isVeryNarrow
                            ? TextAlign.center
                            : TextAlign.left,
                        style: TextStyle(
                          color: const Color(0xFF111827),
                          fontSize: isVeryNarrow ? 13 : 15,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showIndicator) ...[
                      const SizedBox(width: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({this.isCompact = false});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => openApplicationLogin(context),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF111827),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 15,
          vertical: isCompact ? 10 : 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: Text(
        'Login',
        style: TextStyle(
          fontSize: isCompact ? 13 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TryAiButton extends StatefulWidget {
  const _TryAiButton({this.isExpanded = false});

  final bool isExpanded;

  @override
  State<_TryAiButton> createState() => _TryAiButtonState();
}

class _TryAiButtonState extends State<_TryAiButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.035 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: widget.isExpanded
              ? const BoxConstraints(minHeight: 52)
              : const BoxConstraints(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111827), Color(0xFF020617)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF0F172A,
                ).withValues(alpha: _isHovered ? .30 : .16),
                blurRadius: _isHovered ? 24 : 14,
                offset: Offset(0, _isHovered ? 10 : 6),
              ),
              if (_isHovered)
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: .20),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: openApplicationDashboard,
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 13,
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFE0F2FE),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Get Started',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
