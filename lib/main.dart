import 'package:flutter/material.dart';

import 'app.dart';
import 'services/memory_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MemoryCardsApp(repository: MemoryRepository()));
}
