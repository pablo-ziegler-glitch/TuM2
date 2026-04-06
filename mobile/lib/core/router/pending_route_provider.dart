import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ruta pendiente guardada cuando un deep link protegido llega sin sesión activa.
/// Se restaura automáticamente tras login exitoso.
final pendingRouteProvider = StateProvider<String?>((ref) => null);
