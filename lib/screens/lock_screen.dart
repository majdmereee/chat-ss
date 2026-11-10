import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'chat_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  final String _correctPin = "0000";

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      bool canCheck = await auth.canCheckBiometrics;
      if (canCheck) {
        bool authenticated = await auth.authenticate(
          localizedReason: 'تحقق من الهوية للمتابعة',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );
        if (authenticated && mounted) {
          _unlock();
        }
      }
    } catch (_) {}
  }

  void _unlock() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white, size: 64),
              const SizedBox(height: 24),
              const Text(
                'رمز القفل السري',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'الرمز الافتراضي: 0000',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 26, letterSpacing: 12),
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  if (val == _correctPin) {
                    _unlock();
                  }
                },
              ),
              const SizedBox(height: 20),
              IconButton(
                icon: const Icon(Icons.fingerprint, color: Colors.blueAccent, size: 40),
                onPressed: _checkBiometrics,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
