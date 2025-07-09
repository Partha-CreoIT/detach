import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:installed_apps/app_info.dart';
import '../controller/app_list_controller.dart';

class AppListView extends GetView<AppListController> {
  const AppListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Apps to Limit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: controller.goBack,
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final selectedApps =
            controller.allApps
                .where(
                  (app) =>
                      controller.selectedAppPackages.contains(app.packageName),
                )
                .toList();

        final otherApps =
            controller.filteredApps
                .where(
                  (app) =>
                      !controller.selectedAppPackages.contains(app.packageName),
                )
                .toList();

        return Column(
          children: [
            _buildSearchBar(context),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (controller.showSelectedApps.value &&
                      selectedApps.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Selected Apps',
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
                        (context, index) =>
                            _buildAppTile(context, selectedApps[index]),
                        childCount: selectedApps.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider(height: 32)),
                  ],
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
                      (context, index) =>
                          _buildAppTile(context, otherApps[index]),
                      childCount: otherApps.length,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
      floatingActionButton: Obx(
        () =>
            controller.selectedAppPackages.isNotEmpty
                ? FloatingActionButton.extended(
                  onPressed: () {
                    controller.showSelectedApps.value = true;
                    Future.delayed(const Duration(seconds: 2), () {
                      controller.saveAndStartService();
                    });
                  },
                  label: const Text('Continue'),
                  icon: const Icon(Icons.check),
                )
                : const SizedBox.shrink(),
      ),
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
          onChanged: (_) => controller.toggleAppSelection(app),
        ),
        onTap: () => controller.toggleAppSelection(app),
      );
    });
  }
}
