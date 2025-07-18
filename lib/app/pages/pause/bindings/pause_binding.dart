import 'package:get/get.dart';
import '../controllers/pause_controller.dart';

class PauseBinding extends Bindings {
  @override
  void dependencies() {
    print('=== PauseBinding.dependencies() called ===');
    Get.lazyPut<PauseController>(() => PauseController());
  }
}
