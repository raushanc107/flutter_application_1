import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class GoogleDriveAuthService extends ChangeNotifier {
  // Scopes required for the application
  static const List<String> _scopes = [
    drive.DriveApi.driveAppdataScope,
    // Add drive.file scope if you want visible backups later
    // drive.DriveApi.driveFileScope,
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    // Client ID is required for Web
    clientId: kIsWeb
        ? '583834828571-ls1rjlu9e9k21r68mv6ckk4iucfvae8i.apps.googleusercontent.com'
        : null,
    // Server Client ID is required for some flows, but usually optional for pure mobile OAuth
    // Server Client ID is not supported on Web by this plugin version
    serverClientId: kIsWeb
        ? null
        : '583834828571-ls1rjlu9e9k21r68mv6ckk4iucfvae8i.apps.googleusercontent.com',
  );

  GoogleSignInAccount? _currentUser;
  http.Client? _authenticatedClient;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// Initialize and try to restore previous session
  Future<void> init() async {
    _googleSignIn.onCurrentUserChanged.listen((
      GoogleSignInAccount? account,
    ) async {
      _currentUser = account;
      if (_currentUser != null) {
        // Build authenticated client when user changes
        _authenticatedClient = await _googleSignIn.authenticatedClient();
      } else {
        _authenticatedClient = null;
      }
      notifyListeners();
    });

    // Attempt to sign in silently
    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Error signing in silently: $e');
    }
  }

  /// Sign in via Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
      // await _googleSignIn.signOut(); // using disconnect ensures complete cleanup
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  /// Get authenticated HTTP client for API calls
  Future<http.Client?> getAuthenticatedClient() async {
    if (_authenticatedClient != null) {
      return _authenticatedClient;
    }

    // Attempt to refresh/re-create if null but user exists
    if (_currentUser != null) {
      try {
        _authenticatedClient = await _googleSignIn.authenticatedClient();
        return _authenticatedClient;
      } catch (e) {
        debugPrint('Error getting authenticated client: $e');
        return null;
      }
    }

    return null;
  }

  /// Get Drive API client
  Future<drive.DriveApi?> getDriveApi() async {
    final client = await getAuthenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }
}
