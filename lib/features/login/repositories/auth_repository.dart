import 'package:firebase_auth/firebase_auth.dart';
import '../user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> signInWithEmailAndPassword(String email, String password);
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  @override
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user != null) {
      return UserModel(uid: user.uid, email: user.email ?? '');
    }
    return null;
  }
}
