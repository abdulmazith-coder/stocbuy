import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/pages/auth/auth_page.dart';
import 'package:stocbuy_application/application/pages/auth/logout_dialog.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';

class ApplicationDrawer extends StatelessWidget {
  const ApplicationDrawer({
    super.key,
    required this.currentIndex,
    required this.onMenuTap,
  });

  final int currentIndex;
  final ValueChanged<int> onMenuTap;

  static const _menus = <_DrawerMenu>[
    _DrawerMenu('Dashboard', Icons.grid_view_rounded),
    _DrawerMenu('Stocbuy AI', Icons.auto_awesome_rounded),
    _DrawerMenu('IPOs', Icons.trending_up_rounded),
    _DrawerMenu('Pricing', Icons.workspace_premium_outlined),
    _DrawerMenu('Watchlist', Icons.star_border_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth < 360 ? screenWidth : 320.0;
    final horizontalPadding = drawerWidth < 220 ? 10.0 : 18.0;
    final auth = Get.find<AuthController>();

    return Drawer(
      width: drawerWidth,
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DrawerHeader(),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final menu = _menus[index];
                    final isSelected = index == currentIndex;
                    return _DrawerItem(
                      label: menu.label,
                      icon: menu.icon,
                      isSelected: isSelected,
                      onTap: () {
                        Navigator.of(context).maybePop();
                        onMenuTap(index);
                      },
                    );
                  },
                  separatorBuilder: (context, index) => const SizedBox(height: 4),
                  itemCount: _menus.length,
                ),
              ),
              const SizedBox(height: 14),
              Obx(() {
                if (!auth.isLoggedIn.value) {
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                            showAuthDialog(context, initialTab: AuthTab.login);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111827),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Log In'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                            showAuthDialog(context, initialTab: AuthTab.signup);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.lightblue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Sign Up'),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Profile'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).maybePop();
                          showLogoutDialog(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Logout'),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const StocbuyBrandMark(logoSize: 28),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.lightblue : const Color(0xFF111827);

    return Material(
      color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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

class _DrawerMenu {
  const _DrawerMenu(this.label, this.icon);

  final String label;
  final IconData icon;
}

