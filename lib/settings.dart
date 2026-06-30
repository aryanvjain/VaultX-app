import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'change_pin.dart';
import 'pin_lock.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) toggleTheme;

  const SettingsScreen({super.key, required this.toggleTheme});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;
  bool fingerprintEnabled = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    isDarkMode = prefs.getBool("darkMode") ?? false;
    fingerprintEnabled = prefs.getBool("fingerprint") ?? true;

    setState(() {});
  }

  saveFingerprint(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool("fingerprint", value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),

      body: Column(
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: isDarkMode,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool("darkMode", value);

              setState(() {
                isDarkMode = value;
              });

              widget.toggleTheme(value);
            },
          ),

          SwitchListTile(
            title: const Text("Fingerprint Unlock"),
            value: fingerprintEnabled,
            onChanged: (value) {
              setState(() {
                fingerprintEnabled = value;
              });

              saveFingerprint(value);
            },
          ),

          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Change PIN"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePinScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Lock App"),
            onTap: () async {
  bool? result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const PinLockScreen(),
    ),
  );

  if (result == true) {
    Navigator.pop(context); // closes settings screen
  }
},
          ),
        ],
      ),
    );
  }
}
