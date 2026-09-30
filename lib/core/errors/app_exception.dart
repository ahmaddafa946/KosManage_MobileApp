sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthenticationException extends AppException {
  const AuthenticationException([super.message = 'Autentikasi gagal.']);
}

class AuthorizationException extends AppException {
  const AuthorizationException([super.message = 'Anda tidak memiliki akses.']);
}

class ValidationException extends AppException {
  const ValidationException([super.message = 'Data yang dimasukkan belum valid.']);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Koneksi internet bermasalah.']);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Data tidak ditemukan.']);
}

class ConflictException extends AppException {
  const ConflictException([super.message = 'Data bertentangan dengan kondisi saat ini.']);
}

class ServerException extends AppException {
  const ServerException([super.message = 'Server sedang bermasalah.']);
}

class UnknownException extends AppException {
  const UnknownException([super.message = 'Terjadi kesalahan yang tidak diketahui.']);
}
