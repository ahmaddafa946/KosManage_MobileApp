enum AppRole {
  owner,
  tenant;

  static AppRole fromDatabase(String value) {
    switch (value.trim().toLowerCase()) {
      case 'owner':
        return AppRole.owner;
      case 'tenant':
        return AppRole.tenant;
      default:
        throw FormatException('Unknown role: $value');
    }
  }
}
