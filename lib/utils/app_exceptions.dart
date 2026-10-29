// lib/utils/app_exceptions.dart

class AppException implements Exception {
  final String message;
  final String prefix;

  AppException(this.message, this.prefix);

  @override
  String toString() {
    return "$prefix: $message";
  }
}

class FetchDataException extends AppException {
  FetchDataException(String message)
      : super(message, "Erro durante a comunicação");
}

class BadRequestException extends AppException {
  BadRequestException(String message) : super(message, "Requisição inválida");
}

class UnauthorizedException extends AppException {
  UnauthorizedException(String message) : super(message, "Não autorizado");
}

class PokemonNotFoundException extends AppException {
  PokemonNotFoundException(String message)
      : super(message, "Pokémon não encontrado");
}

class LocalDataException extends AppException {
  LocalDataException(String message)
      : super(message, "Erro ao carregar dados locais");
}