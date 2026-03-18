import 'package:flutter_riverpod/flutter_riverpod.dart';

// Profile providers re-export auth providers for convenience
export '../../../auth/presentation/providers/auth_providers.dart'
    show currentUserProvider, currentFirebaseUserProvider, authNotifierProvider;
