import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/home_controller.dart';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildChartCard(context),
            const SizedBox(height: 20),
            _buildInfoCard(context),
            const SizedBox(height: 20),
            _buildAppsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, required BuildContext context}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(padding: const EdgeInsets.all(16.0), child: child),
    );
  }

  Widget _buildChartCard(BuildContext context) {
    return _buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // This is a placeholder for the chart
          Container(
            height: 150,
            color: Colors.grey[200],
            child: const Center(child: Text('Chart Placeholder')),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('View Full Statistics'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    return _buildCard(
      context: context,
      child: Row(
        children: [
          Icon(Icons.shield, color: theme.colorScheme.primary, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'detach is getting even better!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'To make sure detach works consistently, we need you to enable a quick setting.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Get started')),
        ],
      ),
    );
  }

  Widget _buildAppsCard(BuildContext context) {
    final theme = Theme.of(context);
    return _buildCard(
      context: context,
      child: Row(
        children: [
          Icon(Icons.apps, color: theme.colorScheme.primary, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => Text(
                    '${controller.limitedAppsCount.value} apps limited',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You\'ll have to go through detach\'s intervention whenever you open these apps.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => controller.goToAddApps(),
            child: const Text('Add Apps'),
          ),
        ],
      ),
    );
  }
}
