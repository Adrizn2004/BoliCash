import 'package:supabase_flutter/supabase_flutter.dart';

import '../rbac.dart';

class SupabaseService {
  static bool get isConfigured {
    const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    return url.isNotEmpty && anonKey.isNotEmpty;
  }

  static Future<void> initialize() async {
    return;
  }

  static Future<UserRole> resolveUserRole(String userIdentifier) async {
    final normalized = userIdentifier.trim();
    if (normalized.isEmpty || !isConfigured) {
      return UserRole.administradorSistema;
    }

    try {
      final usuario = await Supabase.instance.client
          .from('usuarios')
          .select('id, nombre, email')
          .eq('email', normalized)
          .maybeSingle();

      if (usuario == null || usuario['email'] == null) {
        return UserRole.administradorSistema;
      }

      final response = await Supabase.instance.client
          .from('usuario_roles')
          .select('roles(nombre)')
          .eq('usuario_id', usuario['id'])
          .limit(1);

      if (response.isEmpty) {
        return UserRole.administradorSistema;
      }

      final roleName = response.first['roles'] is Map
          ? response.first['roles']['nombre']
          : null;
      if (roleName == null) {
        return UserRole.administradorSistema;
      }

      return UserRole.fromValue(roleName.toString());
    } catch (_) {
      return UserRole.administradorSistema;
    }
  }

  static Future<bool> validateCredentials({
    String? user,
    String? name,
    required String password,
  }) async {
    if (password.isEmpty || !isConfigured) {
      return false;
    }

    try {
      final normalizedUser = user?.trim() ?? '';
      final normalizedName = name?.trim() ?? '';

      if (normalizedUser.isNotEmpty) {
        final byEmail = await Supabase.instance.client
            .from('usuarios')
            .select('id, nombre, email, pin, estado')
            .eq('email', normalizedUser)
            .eq('pin', password)
            .maybeSingle();

        if (byEmail != null && byEmail['pin'] != null) {
          return true;
        }
      }

      if (normalizedName.isNotEmpty) {
        final byName = await Supabase.instance.client
            .from('usuarios')
            .select('id, nombre, email, pin, estado')
            .eq('nombre', normalizedName)
            .eq('pin', password)
            .maybeSingle();

        if (byName != null && byName['pin'] != null) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}
