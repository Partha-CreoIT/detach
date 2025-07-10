import 'package:get/get.dart';
import 'pause_controller.dart';

class PauseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PauseController>(() => PauseController());
  }
}
