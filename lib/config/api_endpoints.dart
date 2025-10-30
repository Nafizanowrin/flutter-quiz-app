class ApiEndpoints {
  // Central base for auth APIs
  static const String base = 'https://api-staging.onesuite.io/api/auth';

  // Auth
  static const String login = '$base/login';
  static const String logout = '$base/logout';
  static const String me = '$base/user';

  // Profile image upload endpoint
  static const String uploadProfileImage = '$base/user/profile-image';
}

// login.dart
// final response = await http.post(
//   Uri.parse("https://api-staging.onesuite.io/api/auth/login"),
//   body: {"email": email, "password": password},
// );
//
// // signup.dart
// final response = await http.post(
//   Uri.parse("https://api-staging.onesuite.io/api/auth/register"),
//   body: {"email": email, "password": password},
// );
//
// // profile.dart
// final response = await http.get(
//   Uri.parse("https://api-staging.onesuite.io/api/auth/user"),
// );