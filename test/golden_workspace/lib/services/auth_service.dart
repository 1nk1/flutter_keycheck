class AuthService {
  static const userIdKey = 'user_id_key';
  static const tokenKey = 'auth_token_key';

  String getCurrentUserId() {
    return userIdKey;
  }

  String getAuthToken() {
    return tokenKey;
  }
}
