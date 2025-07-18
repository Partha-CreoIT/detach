import 'package:flutter/material.dart';
import '../services/app_blocker_service.dart';
import 'package:figma_squircle/figma_squircle.dart';

/// Example widget demonstrating AppBlockerService usage
class AppBlockerWidget extends StatefulWidget {
  const AppBlockerWidget({Key? key}) : super(key: key);

  @override
  State<AppBlockerWidget> createState() => _AppBlockerWidgetState();
}

class _AppBlockerWidgetState extends State<AppBlockerWidget> {
  final AppBlockerService _blockerService = AppBlockerService();
  Map<String, dynamic> _healthInfo = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() => _isLoading = true);

    try {
      await _blockerService.initialize();
      await _refreshHealthInfo();
    } catch (e) {
      debugPrint('Error initializing service: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshHealthInfo() async {
    final health = await _blockerService.checkServiceHealth();
    setState(() => _healthInfo = health);
  }

  Future<void> _startService() async {
    setState(() => _isLoading = true);

    try {
      final success = await _blockerService.startService();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service started successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start service')),
        );
      }
      await _refreshHealthInfo();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forceRestart() async {
    setState(() => _isLoading = true);

    try {
      await _blockerService.forceRestartService();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service restarted')),
      );
      await _refreshHealthInfo();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testPauseScreen() async {
    try {
      await _blockerService.testPauseScreen('com.example.testapp');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pause screen test launched')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _testBlockedAppOpening() async {
    try {
      await _blockerService
          .testBlockedAppOpening('com.google.android.apps.chromecast.app');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blocked app opening test launched')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _testCompleteTimerFlow() async {
    try {
      await _blockerService.testCompleteTimerFlow(
          'com.google.android.apps.chromecast.app', 10);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Complete timer flow test launched (10s)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _clearPauseFlag() async {
    try {
      await _blockerService.clearPauseFlag();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pause flag cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _blockerService,
      builder: (context, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Blocker Service',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),

                // Service Status
                _buildStatusRow(
                    'Service Running', _blockerService.isServiceRunning),
                _buildStatusRow(
                    'Service Healthy', _blockerService.isServiceHealthy),
                _buildStatusRow(
                    'Blocked Apps', '${_blockerService.blockedApps.length}'),

                const SizedBox(height: 16),

                // Health Info
                if (_healthInfo.isNotEmpty) ...[
                  Text(
                    'Health Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildHealthInfo(),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : _startService,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Start Service',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : _forceRestart,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Force Restart',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : _refreshHealthInfo,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Refresh Health',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isLoading ? null : _testPauseScreen,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Test Pause Screen',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                FilledButton(
                  onPressed: _isLoading ? null : _testBlockedAppOpening,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    minimumSize: const Size(double.infinity, 44),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Test Blocked App Opening',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _isLoading ? null : _testCompleteTimerFlow,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    minimumSize: const Size(double.infinity, 44),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Test Complete Timer Flow (10s)',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _isLoading ? null : _clearPauseFlag,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    minimumSize: const Size(double.infinity, 44),
                    shape: const SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.all(
                        SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Clear Pause Flag (Debug)',
                      style: TextStyle(color: Colors.white)),
                ),

                if (_isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(value),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInfo() {
    return Column(
      children: _healthInfo.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.key),
              Text(entry.value.toString()),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(dynamic value) {
    if (value is bool) {
      return value ? Colors.green : Colors.red;
    }
    if (value is String && value == '0') {
      return Colors.orange;
    }
    return Colors.blue;
  }
}

/// Widget for managing blocked apps
class BlockedAppsWidget extends StatefulWidget {
  const BlockedAppsWidget({Key? key}) : super(key: key);

  @override
  State<BlockedAppsWidget> createState() => _BlockedAppsWidgetState();
}

class _BlockedAppsWidgetState extends State<BlockedAppsWidget> {
  final AppBlockerService _blockerService = AppBlockerService();
  final TextEditingController _packageController = TextEditingController();
  final TextEditingController _timerController = TextEditingController();

  @override
  void dispose() {
    _packageController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _addBlockedApp() async {
    final packageName = _packageController.text.trim();
    if (packageName.isNotEmpty) {
      await _blockerService.blockApp(packageName);
      _packageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blocked: $packageName')),
      );
    }
  }

  Future<void> _removeBlockedApp(String packageName) async {
    await _blockerService.unblockApp(packageName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unblocked: $packageName')),
    );
  }

  Future<void> _launchWithTimer(String packageName) async {
    final durationStr = _timerController.text.trim();
    if (durationStr.isNotEmpty) {
      final duration = int.tryParse(durationStr);
      if (duration != null && duration > 0) {
        await _blockerService.launchAppWithTimer(packageName, duration);
        _timerController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Launched $packageName with ${duration}s timer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _blockerService,
      builder: (context, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blocked Apps (${_blockerService.blockedApps.length})',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),

                // Add new blocked app
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _packageController,
                        decoration: const InputDecoration(
                          labelText: 'Package Name',
                          hintText: 'com.example.app',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _addBlockedApp,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        shape: const SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius.all(
                            SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Block',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Blocked apps list
                if (_blockerService.blockedApps.isEmpty)
                  const Center(
                    child: Text('No blocked apps'),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _blockerService.blockedApps.length,
                    itemBuilder: (context, index) {
                      final packageName = _blockerService.blockedApps[index];
                      return ListTile(
                        title: Text(packageName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Timer launch button
                            IconButton(
                              icon: const Icon(Icons.timer),
                              onPressed: () => _showTimerDialog(packageName),
                            ),
                            // Unblock button
                            IconButton(
                              icon: const Icon(Icons.block),
                              onPressed: () => _removeBlockedApp(packageName),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTimerDialog(String packageName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Launch $packageName with Timer'),
        content: TextField(
          controller: _timerController,
          decoration: const InputDecoration(
            labelText: 'Duration (seconds)',
            hintText: '300',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1A237E),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _launchWithTimer(packageName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              shape: const SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.all(
                  SmoothRadius(cornerRadius: 8, cornerSmoothing: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Launch', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
