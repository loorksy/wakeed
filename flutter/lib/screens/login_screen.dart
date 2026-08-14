import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController userCtrl;
  final passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    userCtrl = TextEditingController(text: app.username);
  }

  @override
  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const WakeedMark(),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('وكيد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            Text('سند حوالة', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'الوضع الليلي / الفاتح',
                        onPressed: app.toggleTheme,
                        icon: Icon(app.isDark ? Icons.dark_mode : Icons.light_mode),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('المستخدم'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: userCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: const InputDecoration(hintText: 'email@example.com'),
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 10),
                  const Text('كلمة المرور'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(hintText: '••••••••'),
                    onSubmitted: (_) => app.login(userCtrl.text, passCtrl.text),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: app.busy ? null : () => app.login(userCtrl.text, passCtrl.text),
                      child: app.busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('دخول'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    app.loginStatus,
                    style: TextStyle(
                      color: app.loginError ? Theme.of(context).colorScheme.error : null,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
