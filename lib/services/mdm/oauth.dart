import "dart:convert";
import "dart:math";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/http_client.dart";
import "package:ciyue/services/platform.dart";
import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:simple_secure_storage/simple_secure_storage.dart";

/// The student identity reported by the school MDM client.
class MdmIdentity {
  final int userId;
  final String name;
  final String username;
  final String serverUrl;

  const MdmIdentity({
    required this.userId,
    required this.name,
    required this.username,
    required this.serverUrl,
  });
}

class MdmTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresInSeconds;

  const MdmTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresInSeconds = 3600,
  });
}

class MdmAuthorizationException implements Exception {
  final String error;
  final String? errorDescription;

  MdmAuthorizationException(this.error, [this.errorDescription]);

  @override
  String toString() => errorDescription == null
      ? "MDM authorization failed: $error"
      : "MDM authorization failed: $error ($errorDescription)";
}

/// OAuth client identity registered in the school backend.
const mdmClientId = String.fromEnvironment(
  "MDM_CLIENT_ID",
  defaultValue: "ciyue",
);
const mdmRedirectUri = "ciyue://oauth/callback";

const _accessTokenKey = "mdm.oauth.accessToken";
const _refreshTokenKey = "mdm.oauth.refreshToken";
const _tokenUserIdKey = "mdm.oauth.tokenUserId";
const _tokenExpiresAtKey = "mdm.oauth.expiresAt";

const _pkceCharset =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";

final _random = Random.secure();

final mdmOAuth = MdmOAuth();

/// Authorization against the school MDM client following the integration
/// contract of com.shxzhy.mdm: PKCE authorization through the MDM activity,
/// token exchange and refresh against the school backend, both tokens stored
/// in the system secure storage.
class MdmOAuth {
  /// Returns the logged-in student, or null when the device is not managed
  /// or no student session exists.
  Future<MdmIdentity?> identity() async {
    final raw = await PlatformMethod.mdmIdentity();
    if (raw == null) return null;

    final userId = raw["user_id"];
    final name = raw["name"];
    final username = raw["username"];
    final serverUrl = raw["server_url"];
    if (userId is! int ||
        name is! String ||
        username is! String ||
        serverUrl is! String ||
        serverUrl.isEmpty) {
      return null;
    }
    return MdmIdentity(
      userId: userId,
      name: name,
      username: username,
      serverUrl: serverUrl,
    );
  }

  /// Runs the full authorization-code flow and stores the resulting tokens.
  ///
  /// The server URL is dynamic (configurable by the school), so it is read
  /// from the MDM client every time instead of being cached.
  Future<MdmTokens> authorize() async {
    final identity = await this.identity();
    if (identity == null) {
      throw MdmAuthorizationException("login_required");
    }

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = base64Url
        .encode(sha256.convert(ascii.encode(codeVerifier)).bytes)
        .replaceAll("=", "");
    final state = _generateCodeVerifier();

    final raw = await PlatformMethod.mdmAuthorize({
      "client_id": mdmClientId,
      "redirect_uri": mdmRedirectUri,
      "code_challenge": codeChallenge,
      "code_challenge_method": "S256",
      "scope": "openid profile",
      "state": state,
    });
    if (raw == null) {
      throw MdmAuthorizationException("mdm_unavailable");
    }

    final error = raw["error"];
    if (error is String) {
      final description = raw["error_description"];
      throw MdmAuthorizationException(
        error,
        description is String ? description : null,
      );
    }

    final code = raw["code"];
    final returnedState = raw["state"];
    if (code is! String || code.isEmpty) {
      throw MdmAuthorizationException("invalid_response");
    }
    if (returnedState is String && returnedState != state) {
      throw MdmAuthorizationException("state_mismatch");
    }

    final tokens = await _tokenRequest(
      serverUrl: identity.serverUrl,
      body: {
        "grant_type": "authorization_code",
        "client_id": mdmClientId,
        "code": code,
        "redirect_uri": mdmRedirectUri,
        "code_verifier": codeVerifier,
      },
    );
    await _storeTokens(identity.userId, tokens);
    return tokens;
  }

  /// Returns tokens valid for [identity], authorizing first when they are
  /// missing or belong to a different student.
  Future<MdmTokens> tokensFor(MdmIdentity identity) async {
    final storedUserId = prefs.getInt(_tokenUserIdKey);
    if (storedUserId == null || storedUserId != identity.userId) {
      await clearTokens();
      return authorize();
    }
    return validAccessToken();
  }

  /// Returns a not-yet-expired access token, refreshing it when needed.
  Future<MdmTokens> validAccessToken() async {
    final accessToken = await SimpleSecureStorage.read(_accessTokenKey);
    final refreshToken = await SimpleSecureStorage.read(_refreshTokenKey);
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw MdmAuthorizationException("login_required");
    }

    final expiresAt = prefs.getInt(_tokenExpiresAtKey) ?? 0;
    if (expiresAt - DateTime.now().millisecondsSinceEpoch > 60 * 1000) {
      return MdmTokens(accessToken: accessToken, refreshToken: refreshToken);
    }

    final identity = await this.identity();
    if (identity == null) {
      throw MdmAuthorizationException("login_required");
    }
    final tokens = await _refreshToken(
      serverUrl: identity.serverUrl,
      refreshToken: refreshToken,
    );
    await _storeTokens(identity.userId, tokens);
    return tokens;
  }

  Future<bool> hasTokens() async {
    final refreshToken = await SimpleSecureStorage.read(_refreshTokenKey);
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  Future<void> clearTokens() async {
    await SimpleSecureStorage.delete(_accessTokenKey);
    await SimpleSecureStorage.delete(_refreshTokenKey);
    await prefs.remove(_tokenUserIdKey);
    await prefs.remove(_tokenExpiresAtKey);
  }

  Future<MdmTokens> _refreshToken({
    required String serverUrl,
    required String refreshToken,
  }) async {
    try {
      final tokens = await _tokenRequest(
        serverUrl: serverUrl,
        body: {
          "grant_type": "refresh_token",
          "client_id": mdmClientId,
          "refresh_token": refreshToken,
        },
      );
      return tokens;
    } on Exception {
      // A rejected refresh token means the session is gone; drop everything
      // so the next attempt starts from a clean authorization.
      await clearTokens();
      rethrow;
    }
  }

  Future<MdmTokens> _tokenRequest({
    required String serverUrl,
    required Map<String, String> body,
  }) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await AppHttp.dio.post<Map<String, dynamic>>(
        "$serverUrl/api/oauth/token",
        data: body,
        options: Options(
          contentType: "application/x-www-form-urlencoded",
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } on DioException {
      throw MdmAuthorizationException("server_unreachable");
    }

    final data = response.data;
    if (data == null) {
      throw MdmAuthorizationException("invalid_response");
    }
    if (response.statusCode != 200) {
      throw MdmAuthorizationException(
        data["error"] is String ? data["error"] as String : "server_error",
        data["error_description"] is String
            ? data["error_description"] as String
            : null,
      );
    }

    final accessToken = data["access_token"];
    final refreshToken = data["refresh_token"];
    final expiresIn = data["expires_in"];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        expiresIn is! num) {
      throw MdmAuthorizationException("invalid_response");
    }
    return MdmTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresInSeconds: expiresIn.toInt(),
    );
  }

  Future<void> _storeTokens(int userId, MdmTokens tokens) async {
    await SimpleSecureStorage.write(_accessTokenKey, tokens.accessToken);
    await SimpleSecureStorage.write(_refreshTokenKey, tokens.refreshToken);
    await prefs.setInt(_tokenUserIdKey, userId);
    await prefs.setInt(
      _tokenExpiresAtKey,
      DateTime.now().millisecondsSinceEpoch + tokens.expiresInSeconds * 1000,
    );
  }
}

String _generateCodeVerifier() => List.generate(
  64,
  (_) => _pkceCharset[_random.nextInt(_pkceCharset.length)],
).join();
