import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/home_controller.dart';
import 'package:installed_apps/app_info.dart';
import 'package:detach/services/theme_service.dart';
import 'widgets/info_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Overview',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 28,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
        actions: [
          // Information button
          IconButton(
            onPressed: () => context.showInfoBottomSheet(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            tooltip: 'How Detach Works',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<ThemeMode>(
            icon: Obx(() {
              final themeService = Get.find<ThemeService>();
              IconData iconData;
              switch (themeService.themeMode.value) {
                case ThemeMode.light:
                  iconData = Icons.light_mode;
                  break;
                case ThemeMode.dark:
                  iconData = Icons.dark_mode;
                  break;
                case ThemeMode.system:
                  iconData = Icons.brightness_auto;
                  break;
              }
              return Icon(iconData);
            }),
            onSelected: (ThemeMode mode) {
              final themeService = Get.find<ThemeService>();
              themeService.setThemeMode(mode);
              // Single status bar update is sufficient
              themeService.updateStatusBarStyle();
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.light,
                child: Row(
                  children: [
                    const Icon(Icons.light_mode, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('Light'),
                    const Spacer(),
                    Obx(() {
                      final themeService = Get.find<ThemeService>();
                      return themeService.themeMode.value == ThemeMode.light
                          ? const Icon(Icons.check, color: Colors.green)
                          : const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.dark,
                child: Row(
                  children: [
                    const Icon(Icons.dark_mode, color: Colors.indigo),
                    const SizedBox(width: 8),
                    const Text('Dark'),
                    const Spacer(),
                    Obx(() {
                      final themeService = Get.find<ThemeService>();
                      return themeService.themeMode.value == ThemeMode.dark
                          ? const Icon(Icons.check, color: Colors.green)
                          : const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
              PopupMenuItem<ThemeMode>(
                value: ThemeMode.system,
                child: Row(
                  children: [
                    const Icon(Icons.brightness_auto, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('System'),
                    const Spacer(),
                    Obx(() {
                      final themeService = Get.find<ThemeService>();
                      return themeService.themeMode.value == ThemeMode.system
                          ? const Icon(Icons.check, color: Colors.green)
                          : const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            _buildSearchBar(context),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Selected Apps Section - Hide during search
                  if (controller.selectedApps.isNotEmpty &&
                      !controller.isSearching) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Selected Apps (${controller.selectedApps.length})',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: controller.clearAllSelected,
                              style: TextButton.styleFrom(
                                textStyle: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildAppTile(
                          context,
                          controller.selectedApps[index],
                        ),
                        childCount: controller.selectedApps.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider(height: 32)),
                  ],
                  // All Apps Section
                  if (!controller.isSearching) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'All Apps',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Search Results or All Apps
                  if (controller.filteredApps.isNotEmpty) ...[
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildAppTile(
                          context,
                          controller.filteredApps[index],
                        ),
                        childCount: controller.filteredApps.length,
                      ),
                    ),
                  ] else if (controller.isSearching) ...[
                    // No search results
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No apps available for your search',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try searching with different keywords',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        onChanged: controller.filterApps,
        style: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Search apps...',
          hintStyle: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant,
        ),
      ),
    );
  }

  Widget _buildAppTile(BuildContext context, AppInfo app) {
    return Obx(() {
      final isSelected = controller.selectedAppPackages.contains(
        app.packageName,
      );
      return ListTile(
        leading: app.icon != null
            ? Image.memory(app.icon!, width: 40, height: 40)
            : const Icon(Icons.apps, size: 40),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(app.name),
        ),
        trailing: Switch(
          value: isSelected,
          onChanged: (_) {
            controller.toggleAppSelection(app);
            controller.saveApps();
          },
        ),
        onTap: () {
          controller.toggleAppSelection(app);
          controller.saveApps();
        },
      );
    });
  }
}
