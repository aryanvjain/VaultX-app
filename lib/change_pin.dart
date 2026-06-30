import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  String enteredPin = "";

  String savedPin = "";

  int step = 1;

  String newPin = "";

  @override
  void initState() {
    super.initState();

    loadPin();
  }

  loadPin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    savedPin = prefs.getString("pin") ?? "";
  }

  savePin(String pin) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.setString("pin", pin);
  }

  enterDigit(String digit) {
    if (enteredPin.length < 4) {
      setState(() {
        enteredPin += digit;
      });

      if (enteredPin.length == 4) {
        handleStep();
      }
    }
  }

  handleStep() {
    if (step == 1) {
      if (enteredPin == savedPin) {
        step = 2;

        enteredPin = "";

        setState(() {});
      } else {
        error("Wrong PIN");
      }
    } else if (step == 2) {
      newPin = enteredPin;

      step = 3;

      enteredPin = "";

      setState(() {});
    } else if (step == 3) {
      if (enteredPin == newPin) {
        savePin(newPin);

        Navigator.pop(context);
      } else {
        error("PIN does not match");
      }
    }
  }

  error(String msg) {
    enteredPin = "";

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    setState(() {});
  }

  Widget numberButton(String n) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(18),
      ),

      onPressed: () => enterDigit(n),

      child: Text(n, style: const TextStyle(fontSize: 24)),
    );
  }

  String getTitle() {
    if (step == 1) {
      return "Enter Current PIN";
    }

    if (step == 2) {
      return "Enter New PIN";
    }

    return "Confirm New PIN";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change PIN")),

      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Text(getTitle(), style: const TextStyle(fontSize: 22)),

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

                  color: filled ? Colors.indigo.shade900 : Colors.grey,
                ),
              );
            }),
          ),

          const SizedBox(height: 40),

          Column(
            children: [
              row("1", "2", "3"),
              row("4", "5", "6"),
              row("7", "8", "9"),
              row("", "0", ""),
            ],
          ),
        ],
      ),
    );
  }

  Widget row(a, b, c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,

        children: [
          a == "" ? const SizedBox(width: 60) : numberButton(a),

          numberButton(b),

          c == "" ? const SizedBox(width: 60) : numberButton(c),
        ],
      ),
    );
  }
}
