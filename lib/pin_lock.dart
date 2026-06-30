import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool fingerprintEnabled = true;
  bool isAuthenticating = false;
  bool fingerprintStarted = false;
  bool biometricAvailable = false;
  Future<void> authenticateFingerprint() async {
    if (isAuthenticating) return;

    setState(() {
      isAuthenticating = true;
    });

    try {
      bool canCheck = await auth.canCheckBiometrics;
      if (!canCheck) {
        setState(() {
          isAuthenticating = false;
        });
        return;
      }

      bool authenticated = await auth.authenticate(
        localizedReason: 'Authenticate to unlock VaultX',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
        ),
      );

      if (authenticated && mounted) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {}

    if (mounted) {
      setState(() {
        isAuthenticating = false;
      });
    }
  }

  Future<void> checkBiometricSupport() async {
    bool canCheck = await auth.canCheckBiometrics;

    if (mounted) {
      setState(() {
        biometricAvailable = canCheck;
      });
    }
  }

  String enteredPin = "";
  String savedPin = "";

  bool isFirstTime = true;
  bool confirmingPin = false;
  String firstPin = "";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadPin(); // wait for pin to load first
      await checkBiometricSupport(); // check device biometric hardware

      if (fingerprintEnabled && biometricAvailable && !fingerprintStarted) {
        fingerprintStarted = true;
        await authenticateFingerprint();
      }
    });
  }

  Future<void> loadPin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? pin = prefs.getString("pin");

    fingerprintEnabled = prefs.getBool("fingerprint") ?? true;

    if (pin == null) {
      isFirstTime = true;
    } else {
      isFirstTime = false;

      savedPin = pin;
    }

    setState(() {});
  }

  savePin(String pin) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString("pin", pin);
  }

  enterDigit(String digit) {
    if (enteredPin.length >= 4) return;

    enteredPin += digit; // update first, outside setState

    setState(() {}); // then trigger rebuild

    if (enteredPin.length == 4) {
      if (isFirstTime) {
        if (!confirmingPin) {
          firstPin = enteredPin;

          enteredPin = "";

          confirmingPin = true;

          setState(() {});
        } else {
          if (enteredPin == firstPin) {
            savePin(enteredPin);

            Navigator.pop(context, true);
          } else {
            enteredPin = "";
            firstPin = "";
            confirmingPin = false;

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("PINs do not match")));

            setState(() {});
          }
        }
      } else {
        if (enteredPin == savedPin) {
          Navigator.pop(context, true);
        } else {
          enteredPin = "";

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Wrong PIN")));

          setState(() {});
        }
      }
    }
  }

  Widget numberButton(String number) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(18),
      ),

      onPressed: () => enterDigit(number),

      child: Text(number, style: const TextStyle(fontSize: 24)),
    );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle;
    String bodyText;

    if (isFirstTime) {
      if (confirmingPin) {
        appBarTitle = "Confirm PIN";
        bodyText = "Please confirm your PIN";
      } else {
        appBarTitle = "Create PIN";
        bodyText = "Please create a PIN";
      }
    } else {
      appBarTitle = "Enter PIN";
      bodyText = "Please enter your PIN here";
    }

    return PopScope(
  canPop: false,
  child: Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),

      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Text(
            bodyText,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              bool filled = index < enteredPin.length;

              return Container(
                margin: const EdgeInsets.all(8),

                width: 16,
                height: 16,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: filled ? Colors.indigo.shade900 : Colors.grey.shade400,
                ),
              );
            }),
          ),

          const SizedBox(height: 40),

          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  numberButton("1"),
                  numberButton("2"),
                  numberButton("3"),
                ],
              ),

              SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  numberButton("4"),
                  numberButton("5"),
                  numberButton("6"),
                ],
              ),

              SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  numberButton("7"),
                  numberButton("8"),
                  numberButton("9"),
                ],
              ),

              SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(width: 70),
                  numberButton("0"),
                  IconButton(
                    icon: Icon(Icons.backspace),
                    onPressed: () {
                      if (enteredPin.isNotEmpty) {
                        setState(() {
                          enteredPin = enteredPin.substring(
                            0,
                            enteredPin.length - 1,
                          );
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (fingerprintEnabled && biometricAvailable)
            IconButton(
              icon: const Icon(Icons.fingerprint, size: 40),
              onPressed: isAuthenticating
                  ? null
                  : () async {
                      await Future.delayed(const Duration(milliseconds: 200));
                      await authenticateFingerprint();
                    },
            ),
        ],
      ),
        ),
  );
}
}
