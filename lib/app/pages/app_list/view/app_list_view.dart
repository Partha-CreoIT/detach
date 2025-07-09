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
            _buildSearchBar(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (selectedApps.isNotEmpty) ...[
                    const SliverToBoxAdapter(
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
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildAppTile(selectedApps[index]),
                        childCount: selectedApps.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider(height: 32)),
                  ],
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'All Apps',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildAppTile(otherApps[index]),
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
                  onPressed: controller.saveAndStartService,
                  label: const Text('Continue'),
                  icon: const Icon(Icons.check),
                )
                : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        onChanged: controller.filterApps,
        decoration: InputDecoration(
          hintText: 'Search apps...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
    );
  }

  Widget _buildAppTile(AppInfo app) {
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
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (_) => controller.toggleAppSelection(app),
          shape: const CircleBorder(),
        ),
        onTap: () => controller.toggleAppSelection(app),
      );
    });
  }
}
