import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();

  // Stream for auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with Google
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Obtain the auth details from the request
      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      print('✅ User signed in with UID: ${userCredential.user!.uid}');
      final bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      // Create a user document in Firestore if it's a new user
      bool shopDetailsFilled = false;
      if (userCredential.user != null) {
        if (isNewUser) {
          await _firestoreService.createUserDocument(user: userCredential.user!, shopName: '', shopAddress: '', phoneNumber: '');
        } else {
          // Correctly check using UID instead of email
          shopDetailsFilled = await _firestoreService.checkShopDetailsFilled(userCredential.user!.uid);
        }
      }

      return {
        'user': userCredential.user,
        'isNewUser': isNewUser,
        'shopDetailsFilled': shopDetailsFilled,
      };
    } catch (e) {
      print(e);
      return null;
    }
  }

  // Sign out
  Future<Map<String, dynamic>?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final user = result.user;
      if (user == null) {
        return null;
      }

      final shopDetailsFilled = await _firestoreService.checkShopDetailsFilled(email);
      print('✅ User signed in with UID: ${user.uid}');

      return {
        'user': user,
        'isNewUser': false, // Not a new user if they are signing in
        'shopDetailsFilled': shopDetailsFilled,
      };
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String shopName,
    required String shopAddress,
    required String phoneNumber,
    File? shopLogo,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = result.user;
      if (user != null) {
        await _firestoreService.createUserDocument(
          user: user,
          shopName: shopName,
          shopAddress: shopAddress,
          phoneNumber: phoneNumber,
          shopLogo: shopLogo,
        );
      }
      return user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
