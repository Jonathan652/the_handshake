import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _momoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _momoCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        momoNumber: _momoCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF064E3B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x3310B981),
                      Color(0x00064E3B),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x1A064E3B),
                      Color(0x00064E3B),
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Join The Handshake secure escrow network',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120F172A),
                          blurRadius: 28,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Identity',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _field(_nameCtrl, 'Full name', Icons.person_outlined),
                          const SizedBox(height: 14),
                          _field(
                              _emailCtrl, 'Email address', Icons.email_outlined,
                              type: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                          _field(_phoneCtrl, 'Phone number (e.g. +256...)',
                              Icons.phone_outlined,
                              type: TextInputType.phone),
                          const SizedBox(height: 14),
                          _field(_momoCtrl, 'MTN MoMo number',
                              Icons.account_balance_wallet_outlined,
                              type: TextInputType.phone),
                          const SizedBox(height: 14),

                          const Text(
                            'Credentials',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            decoration: _inputDecoration(
                              'Password',
                              Icons.lock_outlined,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass),
                              ),
                            ),
                            validator: (v) => v == null || v.length < 6
                                ? 'Minimum 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // Confirm password
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscurePass,
                            decoration: _inputDecoration(
                              'Confirm password',
                              Icons.lock_outlined,
                            ),
                            validator: (v) => v != _passCtrl.text
                                ? 'Passwords do not match'
                                : null,
                          ),

                          // Error
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFDA4AF),
                                ),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFF9F1239),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),

                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF064E3B),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Create account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: _inputDecoration(label, icon),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF0F766E)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.8),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }
}
