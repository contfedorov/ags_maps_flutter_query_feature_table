import 'dart:async';

import 'package:arcgis_maps/arcgis_maps.dart';

class TokenProvider implements ArcGISAuthenticationChallengeHandler {
  final OAuthUserConfiguration _oAuthUserConfiguration;
  Completer<String>? _tokenCompleter;

  TokenProvider({required OAuthUserConfiguration oAuthUserConfiguration})
      : _oAuthUserConfiguration = oAuthUserConfiguration {
    ArcGISEnvironment
        .authenticationManager.arcGISAuthenticationChallengeHandler = this;
  }

  Future<String> getToken() async {
    if (_tokenCompleter != null) return _tokenCompleter!.future;

    _tokenCompleter = Completer<String>();

    try {
      var oauthCredential = await _getCredential();
      var tokenInfo = await oauthCredential.getTokenInfo();

      var token = tokenInfo.accessToken;
      _tokenCompleter?.complete(token);
    } catch (e, stackTrace) {
      _tokenCompleter?.completeError(e, stackTrace);
    }

    return _tokenCompleter!.future;
  }

  @override
  void handleArcGISAuthenticationChallenge(
      ArcGISAuthenticationChallenge challenge) async {
    try {
      // Initiate the sign in process to the OAuth server using the defined user configuration.
      final credential = await _getCredential();

      // Sign in was successful, so continue with the provided credential.
      challenge.continueWithCredential(credential);
    } on ArcGISException catch (error) {
      // Sign in was canceled, or there was some other error.
      final e = (error.wrappedException as ArcGISException?) ?? error;
      if (e.errorType == ArcGISExceptionType.commonUserCanceled) {
        challenge.cancel();
      } else {
        challenge.continueAndFail();
      }
    }
  }

  Future<OAuthUserCredential> _getCredential() async {
    var portalUri = _oAuthUserConfiguration.portalUri;

    OAuthUserCredential oauthCredential;
    var credential = ArcGISEnvironment
        .authenticationManager.arcGISCredentialStore
        .getCredential(uri: portalUri);

    if (credential != null) {
      oauthCredential = credential as OAuthUserCredential;
    } else {
      oauthCredential = await OAuthUserCredential.create(
          configuration: _oAuthUserConfiguration);
      ArcGISEnvironment.authenticationManager.arcGISCredentialStore
          .add(credential: oauthCredential);
    }

    return oauthCredential;
  }
}