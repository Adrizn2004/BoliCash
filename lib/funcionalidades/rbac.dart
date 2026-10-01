enum UserRole {
  administradorSistema('Administrador del Sistema'),
  administradorComercial('Administrador Comercial'),
  supervisor('Supervisor'),
  asesorComercialB2B('Asesor Comercial B2B'),
  reporting('Reporting');

  const UserRole(this.label);

  final String label;

  static UserRole fromValue(String? value) {
    for (final role in UserRole.values) {
      if (role.label == value || role.name == value) {
        return role;
      }
    }
    return UserRole.administradorSistema;
  }
}
