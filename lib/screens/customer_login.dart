import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/localized_text.dart';
import '../services/app_language.dart';

import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/document_upload_consent.dart';

import 'customer_register.dart';
import 'customer_home.dart';
import 'admin_page.dart';
import 'track_page.dart';

Color get _backgroundColor => AppColors.activeBackground;
Color get _primaryColor => AppColors.activePrimary;
Color get _cardColor => AppColors.activeSurface;
Color get _borderColor => AppColors.activeBorder;
Color get _mutedTextColor => AppColors.activeMutedText;

enum _EmailSignInRecoveryAction { google, resetPassword }

class CustomerLogin extends StatefulWidget {
  const CustomerLogin({super.key});

  @override
  State<CustomerLogin> createState() => _CustomerLoginState();
}

class _CustomerLoginState extends State<CustomerLogin> {
  static Future<void>? googleSignInInitialization;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool isGoogleSigningIn = false;
  bool isSendingPasswordReset = false;
  bool obscurePassword = true;

  bool get isAuthenticationBusy =>
      isLoading || isGoogleSigningIn || isSendingPasswordReset;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String getFirebaseErrorMessage(FirebaseAuthException e) {
    if (e.code == "user-not-found") {
      return "Account not found. Please create an account first.";
    }

    if (e.code == "wrong-password") {
      return "Incorrect password.";
    }

    if (e.code == "invalid-email") {
      return "Please enter a valid email address.";
    }

    if (e.code == "invalid-credential") {
      return "The email or app password is incorrect.";
    }

    if (e.code == "network-request-failed") {
      return "Network error. Please check your internet connection.";
    }

    return e.message ?? "Login failed.";
  }

  bool isEmailCredentialFailure(FirebaseAuthException exception) {
    return exception.code == "invalid-credential" ||
        exception.code == "wrong-password" ||
        exception.code == "user-not-found";
  }

  Future<_EmailSignInRecoveryAction?> showEmailSignInRecovery() {
    return showDialog<_EmailSignInRecoveryAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.account_circle_outlined,
            color: _primaryColor,
            size: 38,
          ),
          title: const Text("Unable to sign in with email"),
          content: Text(
            "The email or app password is incorrect. If you created this "
            "account using Google, select Continue with Google—your Google "
            "password cannot be entered in this form. You may also request a "
            "password-reset link to create or replace the separate password "
            "used by this app.",
            style: TextStyle(height: 1.45, color: _mutedTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("CANCEL"),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                _EmailSignInRecoveryAction.resetPassword,
              ),
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text("RESET APP PASSWORD"),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                _EmailSignInRecoveryAction.google,
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text("CONTINUE WITH GOOGLE"),
            ),
          ],
        );
      },
    );
  }

  String getGoogleSignInErrorMessage(FirebaseAuthException e) {
    if (e.code == "popup-closed-by-user" ||
        e.code == "web-context-canceled" ||
        e.code == "canceled" ||
        e.code == "cancelled") {
      return "Google sign-in was cancelled.";
    }

    if (e.code == "popup-blocked") {
      return "The Google sign-in window was blocked. Allow pop-ups and try again.";
    }

    if (e.code == "account-exists-with-different-credential") {
      return "This Google email is already registered with a password. Sign in with your email and password instead.";
    }

    if (e.code == "operation-not-allowed") {
      return "Google sign-in is not enabled for this project yet. Please contact the administrator.";
    }

    if (e.code == "network-request-failed") {
      return "Network error. Please check your internet connection.";
    }

    if (e.code == "too-many-requests") {
      return "Too many sign-in attempts. Please wait before trying again.";
    }

    return e.message ?? "Google sign-in failed.";
  }

  String getNativeGoogleSignInErrorMessage(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return "Google sign-in was cancelled.";
      case GoogleSignInExceptionCode.interrupted:
        return "Google sign-in was interrupted. Please try again.";
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return "Google sign-in is not configured correctly for this app. Please contact the administrator.";
      case GoogleSignInExceptionCode.uiUnavailable:
        return "Google sign-in could not open on this device. Please try again.";
      default:
        return e.description ?? "Google sign-in failed.";
    }
  }

  bool usesGoogleProvider(User user) {
    return user.providerData.any(
      (provider) => provider.providerId == "google.com",
    );
  }

  String getPasswordResetErrorMessage(FirebaseAuthException e) {
    if (e.code == "invalid-email") {
      return "Please enter a valid email address.";
    }

    if (e.code == "user-not-found") {
      return "No account was found for that email address.";
    }

    if (e.code == "too-many-requests") {
      return "Too many attempts. Please wait before trying again.";
    }

    if (e.code == "network-request-failed") {
      return "Network error. Please check your internet connection.";
    }

    return e.message ?? "Unable to send the password reset email.";
  }

  Future<void> resetPassword() async {
    String resetEmailValue = emailController.text.trim();
    final formKey = GlobalKey<FormState>();

    final String? resetEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(Icons.lock_reset_rounded, color: _primaryColor, size: 36),
          title: const Text("Reset Password"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enter your registered email. We will send a secure link "
                  "where you can create a separate password for this app. "
                  "Do not enter or reuse your Google password here.",
                  style: TextStyle(height: 1.4, color: _mutedTextColor),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  initialValue: resetEmailValue,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: appText("Email"),
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? "";

                    if (email.isEmpty ||
                        !RegExp(
                          r"^[^@\s]+@[^@\s]+\.[^@\s]+$",
                        ).hasMatch(email)) {
                      return "Enter a valid email address";
                    }

                    return null;
                  },
                  onChanged: (value) {
                    resetEmailValue = value.trim();
                  },
                  onFieldSubmitted: (value) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(dialogContext, value.trim());
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("CANCEL"),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, resetEmailValue);
                }
              },
              child: const Text("SEND RESET LINK"),
            ),
          ],
        );
      },
    );

    if (resetEmail == null || !mounted) return;

    setState(() {
      isSendingPasswordReset = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: resetEmail);

      if (!mounted) return;

      emailController.text = resetEmail;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password reset email sent. Open the link to create a new password.",
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getPasswordResetErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() {
          isSendingPasswordReset = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> createGoogleCustomerProfile(
    User user, {
    required bool isNewAuthUser,
  }) async {
    if (!usesGoogleProvider(user) ||
        !user.emailVerified ||
        (user.email?.trim().isEmpty ?? true)) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Google could not provide a verified email address. Please choose a different Google account.",
          ),
        ),
      );
      return null;
    }

    final consentAccepted = await requestDocumentUploadConsent(context);
    if (!mounted) return null;

    if (!consentAccepted) {
      if (isNewAuthUser) {
        try {
          await user.delete();
        } catch (_) {
          await FirebaseAuth.instance.signOut();
        }
      } else {
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Account was not created. Document upload authorization is required.",
          ),
        ),
      );
      return null;
    }

    final String verifiedEmail = user.email!.trim();
    final String googleName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : verifiedEmail.split("@").first;
    final profile = <String, dynamic>{
      "uid": user.uid,
      "fullName": googleName,
      "email": verifiedEmail,
      "municipality": "",
      "role": "customer",
      "authProvider": "google.com",
      "emailVerified": true,
      "documentUploadConsent": true,
      "documentUploadConsentVersion": documentUploadConsentVersion,
      "documentUploadConsentAcceptedAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "lastLoginAt": FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .set(profile);
    return profile;
  }

  Future<void> routeAuthenticatedUser(
    User user, {
    required String loginEmail,
    bool allowGoogleProfileCreation = false,
    bool isNewAuthUser = false,
  }) async {
    final profileReference = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid);
    DocumentSnapshot<Map<String, dynamic>> userDoc = await profileReference
        .get();
    Map<String, dynamic>? data = userDoc.data();

    if (data == null && allowGoogleProfileCreation) {
      data = await createGoogleCustomerProfile(
        user,
        isNewAuthUser: isNewAuthUser,
      );
    }

    if (data == null) {
      if (FirebaseAuth.instance.currentUser == null) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account profile not found. Please contact support."),
        ),
      );
      return;
    }

    final String role = (data["role"] ?? "").toString().trim().toLowerCase();
    if (!mounted) return;

    if (role == "admin") {
      await profileReference.set({
        "lastLoginAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPage()),
      );
      return;
    }

    if (role == "customer" || role == "user") {
      if (!user.emailVerified) {
        try {
          await user.sendEmailVerification();
        } on FirebaseAuthException {
          // A previously sent link may still be valid. Login remains blocked
          // until Firebase confirms that the address has been verified.
        }
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Verify your email before signing in. We sent a verification link to your email address.",
            ),
          ),
        );
        return;
      }

      final authEmail = user.email?.trim() ?? loginEmail;
      final updates = <String, dynamic>{
        "lastLoginAt": FieldValue.serverTimestamp(),
        "emailVerified": true,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      if (authEmail.isNotEmpty && data["email"]?.toString() != authEmail) {
        updates.addAll({
          "email": authEmail,
          "pendingEmail": FieldValue.delete(),
          "emailChangeRequestedAt": FieldValue.delete(),
        });
      }
      await profileReference.set(updates, SetOptions(merge: true));

      loggedInCustomerNameNotifier.value =
          (data["fullName"] ?? user.displayName ?? "").toString();
      loggedInCustomerEmailNotifier.value = authEmail;
      loggedInCustomerIdNotifier.value = user.uid;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHome()),
      );
      return;
    }

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Access denied. This account has no valid role."),
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    setState(() {
      isGoogleSigningIn = true;
    });

    try {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({"prompt": "select_account"});
      final UserCredential credential;
      if (kIsWeb) {
        credential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn.instance;
        await (googleSignInInitialization ??= googleSignIn.initialize());

        final GoogleSignInAccount googleAccount = await googleSignIn
            .authenticate();
        final String? idToken = googleAccount.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw FirebaseAuthException(
            code: "missing-google-id-token",
            message: "Google did not return a secure ID token.",
          );
        }

        final OAuthCredential googleCredential = GoogleAuthProvider.credential(
          idToken: idToken,
        );
        credential = await FirebaseAuth.instance.signInWithCredential(
          googleCredential,
        );
      }
      final User? user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: "user-not-found",
          message: "Google account was not returned.",
        );
      }

      await routeAuthenticatedUser(
        user,
        loginEmail: user.email?.trim() ?? "",
        allowGoogleProfileCreation: true,
        isNewAuthUser: credential.additionalUserInfo?.isNewUser ?? false,
      );
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getNativeGoogleSignInErrorMessage(e))),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getGoogleSignInErrorMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Google sign-in failed: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isGoogleSigningIn = false;
        });
      }
    }
  }

  Future<void> login() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter credentials")));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final User? user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: "user-not-found",
          message: "Account not found.",
        );
      }

      await user.reload();
      await routeAuthenticatedUser(
        FirebaseAuth.instance.currentUser ?? user,
        loginEmail: email,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (isEmailCredentialFailure(e)) {
        final recoveryAction = await showEmailSignInRecovery();
        if (!mounted || recoveryAction == null) return;

        setState(() {
          isLoading = false;
        });

        if (recoveryAction == _EmailSignInRecoveryAction.google) {
          await signInWithGoogle();
        } else {
          await resetPassword();
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFirebaseErrorMessage(e))));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration formDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: appText(label),
      hintText: appText(hint),
      prefixIcon: Icon(icon, color: _primaryColor),
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(
        color: _mutedTextColor,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: _mutedTextColor),
      filled: true,
      fillColor: _backgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryColor, width: 1.5),
      ),
    );
  }

  Widget webStaticLogin(Widget child) {
    if (!kIsWeb) return child;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _backgroundColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _primaryColor,
          onPrimary: Colors.white,
          surface: _cardColor,
          onSurface: _primaryColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 3,
            shadowColor: _primaryColor.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(overscroll: false, scrollbars: !kIsWeb),
              child: webStaticLogin(
                SingleChildScrollView(
                  physics: kIsWeb
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    children: [
                      Container(
                        height: 92,
                        width: 92,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withValues(alpha: 0.16),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_circle_rounded,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),

                      const SizedBox(height: 22),

                      Text(
                        "Account Login",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _primaryColor,
                          letterSpacing: 0.8,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "Continue as a walk-in, or use your registered account.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                          color: _mutedTextColor,
                        ),
                      ),

                      const SizedBox(height: 28),

                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 380),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withValues(alpha: 0.16),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.directions_walk_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Walk-In Customer",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Get your queue number at the center, then track your position here without an account.",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: isAuthenticationBusy
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const TrackPage(
                                              isWalkInTracking: true,
                                            ),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.search_rounded),
                                label: const Text(
                                  "CONTINUE AS WALK-IN",
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 50,
                            child: Divider(color: _borderColor),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              "ACCOUNT",
                              style: TextStyle(
                                color: _mutedTextColor,
                                fontSize: 12,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Divider(color: _borderColor),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 380),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: _borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withValues(alpha: 0.08),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Login or Create Account",
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primaryColor,
                                  backgroundColor: _cardColor,
                                  side: BorderSide(color: _borderColor),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: isAuthenticationBusy
                                    ? null
                                    : signInWithGoogle,
                                child: isGoogleSigningIn
                                    ? SizedBox(
                                        height: 21,
                                        width: 21,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: _primaryColor,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _GoogleLogo(size: 21),
                                          SizedBox(width: 10),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                "CONTINUE WITH GOOGLE",
                                                maxLines: 1,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(child: Divider(color: _borderColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    "OR SIGN IN WITH EMAIL",
                                    style: TextStyle(
                                      color: _mutedTextColor,
                                      fontSize: 11,
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: _borderColor)),
                              ],
                            ),

                            const SizedBox(height: 16),

                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: formDecoration(
                                label: "Email",
                                hint: "Enter your email address",
                                icon: Icons.email_outlined,
                              ),
                            ),

                            const SizedBox(height: 16),

                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              enableSuggestions: false,
                              autocorrect: false,
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: formDecoration(
                                label: "Password",
                                hint: "Enter your password",
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  tooltip: obscurePassword
                                      ? "Show password"
                                      : "Hide password",
                                  onPressed: isAuthenticationBusy
                                      ? null
                                      : () {
                                          setState(() {
                                            obscurePassword = !obscurePassword;
                                          });
                                        },
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: _primaryColor,
                                  ),
                                ),
                              ),
                            ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isAuthenticationBusy
                                    ? null
                                    : resetPassword,
                                child: Text(
                                  isSendingPasswordReset
                                      ? "Sending reset link..."
                                      : "Forgot Password?",
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: isAuthenticationBusy ? null : login,
                                child: isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text("LOGIN"),
                              ),
                            ),

                            const SizedBox(height: 14),

                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "No account yet?",
                                  style: TextStyle(
                                    color: _mutedTextColor,
                                    fontSize: 13.5,
                                  ),
                                ),
                                TextButton(
                                  onPressed: isAuthenticationBusy
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const CustomerRegister(),
                                            ),
                                          );
                                        },
                                  child: Text(
                                    "Create Account",
                                    style: TextStyle(
                                      color: _primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        "Queue · Appointment · Tracking",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _mutedTextColor,
                          fontSize: 13.5,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: const _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 18, size.height / 18);

    Paint fill(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bluePath = Path()
      ..moveTo(17.64, 9.2045)
      ..relativeCubicTo(0, -0.638, -0.0573, -1.2518, -0.1636, -1.8409)
      ..lineTo(9, 7.3636)
      ..relativeLineTo(0, 3.4818)
      ..relativeLineTo(4.8436, 0)
      ..relativeCubicTo(-0.2086, 1.125, -0.8427, 2.0782, -1.7964, 2.7164)
      ..relativeLineTo(0, 2.2582)
      ..relativeLineTo(2.9082, 0)
      ..relativeCubicTo(1.702, -1.5668, 2.6846, -3.8741, 2.6846, -6.6155)
      ..close();

    final greenPath = Path()
      ..moveTo(9, 18)
      ..relativeCubicTo(2.43, 0, 4.4673, -0.8059, 5.9564, -2.18)
      ..relativeLineTo(-2.9082, -2.2582)
      ..relativeCubicTo(-0.8059, 0.54, -1.8354, 0.8591, -3.0482, 0.8591)
      ..relativeCubicTo(-2.3441, 0, -4.3286, -1.5845, -5.0373, -3.7104)
      ..lineTo(0.9564, 10.7105)
      ..relativeLineTo(0, 2.3327)
      ..cubicTo(2.4373, 15.9832, 5.4818, 18, 9, 18)
      ..close();

    final yellowPath = Path()
      ..moveTo(3.9627, 10.7105)
      ..arcToPoint(
        const Offset(3.6818, 9),
        radius: const Radius.elliptical(5.4099, 5.4099),
        clockwise: true,
      )
      ..relativeCubicTo(0, -0.5932, 0.1018, -1.17, 0.2809, -1.7105)
      ..lineTo(3.9627, 4.9568)
      ..lineTo(0.9564, 4.9568)
      ..arcToPoint(
        const Offset(0, 9),
        radius: const Radius.elliptical(9.0043, 9.0043),
        clockwise: false,
      )
      ..relativeCubicTo(0, 1.4527, 0.3477, 2.8273, 0.9564, 4.0432)
      ..relativeLineTo(3.0063, -2.3327)
      ..close();

    final redPath = Path()
      ..moveTo(9, 3.5791)
      ..relativeCubicTo(1.3214, 0, 2.5077, 0.4545, 3.4418, 1.3459)
      ..relativeLineTo(2.5814, -2.5814)
      ..cubicTo(13.4632, 0.8918, 11.43, 0, 9, 0)
      ..cubicTo(5.4818, 0, 2.4373, 2.0168, 0.9564, 4.9568)
      ..relativeLineTo(3.0063, 2.3327)
      ..cubicTo(4.6714, 5.1636, 6.6559, 3.5791, 9, 3.5791)
      ..close();

    canvas.drawPath(bluePath, fill(_blue));
    canvas.drawPath(greenPath, fill(_green));
    canvas.drawPath(yellowPath, fill(_yellow));
    canvas.drawPath(redPath, fill(_red));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
