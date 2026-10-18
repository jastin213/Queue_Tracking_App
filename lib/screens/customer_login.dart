import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/localized_text.dart';
import '../services/app_language.dart';

import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/document_upload_consent.dart';
import '../services/remembered_login.dart';

import 'customer_register.dart';
import 'customer_home.dart';
import 'admin_page.dart';
import 'track_page.dart';

Color get _primaryColor => AppColors.activePrimary;
Color get _mutedTextColor => AppColors.activeMutedText;

const Color _loginNavy = AppColors.primary;
const Color _loginMuted = AppColors.mutedText;
const Color _loginBorder = AppColors.border;
const Color _loginFieldFill = AppColors.softPrimary;

class _LoginViewport extends StatelessWidget {
  const _LoginViewport({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktopLayout = constraints.maxWidth >= 1000;
        final compact = constraints.maxWidth < 600;
        final horizontalPadding = compact ? 18.0 : 28.0;
        final animatedChild = TweenAnimationBuilder<double>(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: 1),
          child: child,
          builder: (context, value, content) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - value)),
                child: content,
              ),
            );
          },
        );

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE7F6FB),
                      Color(0xFFD7F2F4),
                      Color(0xFFB8E8EC),
                    ],
                  ),
                ),
              ),
              const Positioned(
                top: -170,
                left: -90,
                child: _LoginBackdropBlob(
                  width: 780,
                  height: 370,
                  colors: [Color(0x99C9EAF5), Color(0x339DDCE7)],
                ),
              ),
              const Positioned(
                top: -115,
                right: -120,
                child: _LoginBackdropBlob(
                  width: 600,
                  height: 360,
                  colors: [Color(0x8B72CDD9), Color(0x307CE0D3)],
                ),
              ),
              const Positioned(
                bottom: -220,
                left: -100,
                child: _LoginBackdropBlob(
                  width: 760,
                  height: 480,
                  colors: [Color(0x8B64C8DA), Color(0x257BD4E5)],
                ),
              ),
              const Positioned(
                bottom: -190,
                right: -80,
                child: _LoginBackdropBlob(
                  width: 720,
                  height: 420,
                  colors: [Color(0x8AADEAEF), Color(0x3572D5D0)],
                ),
              ),
              if (desktopLayout)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 1440,
                          height: 720,
                          child: animatedChild,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SafeArea(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(overscroll: false, scrollbars: false),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        24,
                        horizontalPadding,
                        28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: animatedChild,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LoginBackdropBlob extends StatelessWidget {
  const _LoginBackdropBlob({
    required this.width,
    required this.height,
    required this.colors,
  });

  final double width;
  final double height;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.12,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          gradient: LinearGradient(colors: colors),
        ),
      ),
    );
  }
}

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
  bool rememberMe = false;

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
    required bool rememberSession,
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

      await saveRememberedLoginPreference(rememberSession);

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

      await saveRememberedLoginPreference(rememberSession);

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
      await prepareLoginSession(remember: rememberMe);
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
        rememberSession: rememberMe,
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
      await prepareLoginSession(remember: rememberMe);
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
        rememberSession: rememberMe,
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
      prefixIcon: Icon(icon, color: _loginNavy, size: 21),
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(
        color: _loginMuted,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: _loginMuted),
      filled: true,
      fillColor: _loginFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _loginBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _loginNavy, width: 1.6),
      ),
    );
  }

  Widget _buildBrandHeader({required bool compact}) {
    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          "NPJN SMART QUEUE MANAGEMENT AND APPOINTMENT SYSTEM",
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 27 : 36,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          "Book appointments and track your queue with ease.",
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: const Color(0xFFE1F3F5),
            fontSize: compact ? 14 : 17,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefactorPhoto() {
    return CustomPaint(
      foregroundPainter: const _OrganicPhotoBorderPainter(),
      child: ClipPath(
        clipper: const _OrganicPhotoClipper(),
        child: Image.asset(
          'assets/images/npjn_emission_center_login.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0.1, 0),
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildWalkInCard(BuildContext context, {required bool compact}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 20 : 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(compact ? 17 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2036).withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(compact ? 20 : 24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.72),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 42 : 48,
                    height: compact ? 42 : 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.directions_walk_rounded,
                      color: Colors.white,
                      size: compact ? 25 : 28,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      "Walk-In Customer",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 17 : 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 12),
              Text(
                "Get your queue number at the center, then track your position here without an account.",
                style: TextStyle(
                  color: const Color(0xFFE6EFF4),
                  fontSize: compact ? 13 : 14.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: compact ? 13 : 16),
              SizedBox(
                width: double.infinity,
                height: compact ? 48 : 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _loginNavy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: isAuthenticationBusy
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const TrackPage(isWalkInTracking: true),
                            ),
                          );
                        },
                  icon: const Icon(Icons.search_rounded, size: 21),
                  label: const Text(
                    "Track Walk-In Queue",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandPanel(BuildContext context, {required bool compact}) {
    final panel = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123C5C), Color(0xFF087F8C), Color(0xFF159CA5)],
          stops: [0, 0.56, 1],
        ),
      ),
      child: compact
          ? Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBrandHeader(compact: true),
                  const SizedBox(height: 18),
                  SizedBox(height: 285, child: _buildBenefactorPhoto()),
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: _buildWalkInCard(context, compact: true),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 56,
                  right: 46,
                  top: 44,
                  child: _buildBrandHeader(compact: false),
                ),
                Positioned(
                  left: 36,
                  right: 34,
                  top: 166,
                  bottom: 58,
                  child: _buildBenefactorPhoto(),
                ),
                Positioned(
                  left: 92,
                  right: 92,
                  bottom: 28,
                  child: _buildWalkInCard(context, compact: false),
                ),
              ],
            ),
    );

    if (compact) {
      return ClipRRect(borderRadius: BorderRadius.circular(26), child: panel);
    }
    return panel;
  }

  Widget _buildAccountContent(BuildContext context, {required bool compact}) {
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_person_outlined, color: _loginNavy, size: 27),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  "Account Login",
                  style: TextStyle(
                    color: _loginNavy,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Sign in to manage your appointments and queue updates.",
              style: TextStyle(
                color: _loginMuted,
                fontSize: 13.5,
                height: 1.38,
              ),
            ),
          ),
          SizedBox(height: compact ? 18 : 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _loginNavy,
                backgroundColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.16),
                side: const BorderSide(color: _loginBorder),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: isAuthenticationBusy ? null : signInWithGoogle,
              child: isGoogleSigningIn
                  ? const SizedBox(
                      height: 21,
                      width: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: _loginNavy,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoogleLogo(size: 22),
                        SizedBox(width: 11),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "CONTINUE WITH GOOGLE",
                              maxLines: 1,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: Divider(color: _loginBorder)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "OR SIGN IN WITH EMAIL",
                  style: TextStyle(
                    color: _loginMuted,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(child: Divider(color: _loginBorder)),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            scrollPadding: const EdgeInsets.only(bottom: 140),
            style: const TextStyle(
              color: _loginNavy,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            decoration: formDecoration(
              label: "Email",
              hint: "Enter your email address",
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            enableSuggestions: false,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) {
              if (!isAuthenticationBusy) login();
            },
            scrollPadding: const EdgeInsets.only(bottom: 140),
            style: const TextStyle(
              color: _loginNavy,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            decoration: formDecoration(
              label: "Password",
              hint: "Enter your password",
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                tooltip: obscurePassword ? "Show password" : "Hide password",
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
                  color: _loginNavy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isAuthenticationBusy
                      ? null
                      : () {
                          setState(() {
                            rememberMe = !rememberMe;
                          });
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: rememberMe,
                        onChanged: isAuthenticationBusy
                            ? null
                            : (value) {
                                setState(() {
                                  rememberMe = value ?? false;
                                });
                              },
                        activeColor: _loginNavy,
                        visualDensity: VisualDensity.compact,
                      ),
                      const Flexible(
                        child: Text(
                          "Remember Me",
                          maxLines: 1,
                          style: TextStyle(
                            color: _loginMuted,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: isAuthenticationBusy ? null : resetPassword,
                child: Text(
                  isSendingPasswordReset
                      ? "Sending reset link..."
                      : "Forgot Password?",
                  style: const TextStyle(
                    color: _loginNavy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            height: 54,
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
                  : const Text("SIGN IN"),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                "No account yet?",
                style: TextStyle(color: _loginMuted, fontSize: 13.5),
              ),
              TextButton(
                onPressed: isAuthenticationBusy
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomerRegister(),
                          ),
                        );
                      },
                child: const Text(
                  "Create Account",
                  style: TextStyle(
                    color: _loginNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveLogin(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktopLayout = constraints.maxWidth >= 1000;

        if (desktopLayout) {
          return Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A2E43).withValues(alpha: 0.24),
                        blurRadius: 38,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 8,
                        child: _buildBrandPanel(context, compact: false),
                      ),
                      Expanded(
                        flex: 5,
                        child: ColoredBox(
                          color: Colors.white,
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 46,
                                vertical: 34,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 440,
                                ),
                                child: _buildAccountContent(
                                  context,
                                  compact: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Queue · Appointment · Tracking",
                style: TextStyle(
                  color: _loginNavy,
                  fontSize: 13,
                  letterSpacing: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBrandPanel(context, compact: true),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A2E43).withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: _buildAccountContent(context, compact: true),
            ),
            const SizedBox(height: 18),
            const Text(
              "Queue · Appointment · Tracking",
              style: TextStyle(
                color: _loginNavy,
                fontSize: 12.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFDDF3F6),
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _loginNavy,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: _loginNavy,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _loginNavy,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: _loginNavy.withValues(alpha: 0.24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: _LoginViewport(child: _buildResponsiveLogin(context)),
      ),
    );
  }
}

Path _organicPhotoPath(Size size) {
  return Path()
    ..moveTo(0, size.height * 0.19)
    ..cubicTo(
      size.width * 0.08,
      size.height * 0.01,
      size.width * 0.27,
      0,
      size.width * 0.43,
      size.height * 0.1,
    )
    ..cubicTo(
      size.width * 0.62,
      size.height * 0.22,
      size.width * 0.74,
      size.height * 0.02,
      size.width * 0.9,
      size.height * 0.08,
    )
    ..cubicTo(
      size.width,
      size.height * 0.13,
      size.width,
      size.height * 0.35,
      size.width * 0.98,
      size.height * 0.55,
    )
    ..cubicTo(
      size.width * 0.96,
      size.height * 0.78,
      size.width * 0.79,
      size.height * 0.97,
      size.width * 0.59,
      size.height * 0.94,
    )
    ..cubicTo(
      size.width * 0.36,
      size.height * 0.9,
      size.width * 0.16,
      size.height,
      size.width * 0.05,
      size.height * 0.82,
    )
    ..cubicTo(
      -size.width * 0.02,
      size.height * 0.69,
      -size.width * 0.02,
      size.height * 0.37,
      0,
      size.height * 0.19,
    )
    ..close();
}

class _OrganicPhotoClipper extends CustomClipper<Path> {
  const _OrganicPhotoClipper();

  @override
  Path getClip(Size size) => _organicPhotoPath(size);

  @override
  bool shouldReclip(covariant _OrganicPhotoClipper oldClipper) => false;
}

class _OrganicPhotoBorderPainter extends CustomPainter {
  const _OrganicPhotoBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _organicPhotoPath(size);
    final glowPaint = Paint()
      ..color = const Color(0xFF8DEEFF).withValues(alpha: 0.54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final borderPaint = Paint()
      ..color = const Color(0xFFC3F7FF).withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _OrganicPhotoBorderPainter oldDelegate) => false;
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
