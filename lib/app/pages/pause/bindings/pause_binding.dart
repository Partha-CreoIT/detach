import 'package:get/get.dart';
import '../controllers/pause_controller.dart';
class PauseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PauseController>(() => PauseController());
  }
}
