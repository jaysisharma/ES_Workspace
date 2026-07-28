class AuthErrorMapper {
  static String map(String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('user-not-found') ||
        lowerError.contains('no user found')) {
      return 'No account found with this email.';
    }
    if (lowerError.contains('email-already-in-use') ||
        lowerError.contains('email already exists')) {
      return 'An account already exists with this email. Please Sign In instead.';
    }
    if (lowerError.contains('wrong-password') ||
        lowerError.contains('invalid-credential') ||
        lowerError.contains('malformed') ||
        lowerError.contains('expired')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (lowerError.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (lowerError.contains('weak-password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    if (lowerError.contains('network-request-failed')) {
      return 'Connection error. Please check your internet.';
    }
    if (lowerError.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (lowerError.contains('user-disabled')) {
      return 'This account has been disabled.';
    }
    if (lowerError.contains('operation-not-allowed')) {
      return 'Login is currently disabled. Contact support.';
    }

    // Default friendly message if we don't recognize the specific code
    if (lowerError.contains('firebaseauth error') ||
        lowerError.contains('internal-error')) {
      return 'Authentication failed. Please check your credentials and try again.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
