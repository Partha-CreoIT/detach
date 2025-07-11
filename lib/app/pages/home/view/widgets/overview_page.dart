import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:installed_apps/app_info.dart';
import '../../controller/home_controller.dart';
import 'package:figma_squircle/figma_squircle.dart';

class OverviewPage extends GetView<HomeController> {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Overview',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  // Selected Apps Section
                  if (controller.selectedApps.isNotEmpty) ...[
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
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: controller.clearAllSelected,
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'All Apps',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildAppTile(
                        context,
                        controller.filteredApps[index],
                      ),
                      childCount: controller.filteredApps.length,
                    ),
                  ),
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
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search apps...',
          hintStyle: TextStyle(
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
        leading:
            app.icon != null
                ? Image.memory(app.icon!, width: 40, height: 40)
                : const Icon(Icons.apps, size: 40),
        title: Text(app.name),
        subtitle: Text(
          app.packageName,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
