import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'kayit_sayfasi.dart';
import 'sifre_sifirlama_sayfasi.dart';

/// Giris Sayfasi - Email/sifre ile giris
class GirisSayfasi extends StatefulWidget {
  final AuthProvider authProvider;
  final VoidCallback onLoginSuccess;

  const GirisSayfasi({
    super.key,
    required this.authProvider,
    required this.onLoginSuccess,
  });

  @override
  State<GirisSayfasi> createState() => _GirisSayfasiState();
}

class _GirisSayfasiState extends State<GirisSayfasi> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _useFirebase = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    bool success;
    if (_useFirebase) {
      success = await widget.authProvider.loginWithFirebase(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await widget.authProvider.loginDirect(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
    if (success && mounted) {
      widget.onLoginSuccess();
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => KayitSayfasi(
          authProvider: widget.authProvider,
          onRegisterSuccess: widget.onLoginSuccess,
        ),
      ),
    );
  }

  void _navigateToPasswordReset() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SifreSifirlamaSayfasi(
          authProvider: widget.authProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.authProvider,
        builder: (BuildContext context, Widget? child) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 40),
                    _buildForm(),
                    const SizedBox(height: 16),
                    if (widget.authProvider.state.errorMessage != null)
                      _buildError(widget.authProvider.state.errorMessage!),
                    const SizedBox(height: 24),
                    _buildLoginButton(),
                    const SizedBox(height: 16),
                    _buildLinks(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.gridMor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.eco,
            color: AppColors.kartEnerjiUretim,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SmartFarm XR',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.notrBeyaz,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Akilli Ciftlik Yonetim Sistemi',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.notrGri500,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return 'E-posta gerekli';
              }
              if (!value.contains('@')) {
                return 'Gecerli bir e-posta girin';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Sifre',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (String? value) {
              if (value == null || value.isEmpty) {
                return 'Sifre gerekli';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: _useFirebase,
                onChanged: (bool value) {
                  setState(() {
                    _useFirebase = value;
                  });
                },
                activeColor: AppColors.gridMor,
              ),
              Text(
                _useFirebase ? 'Firebase ile giris' : 'Dogrudan giris',
                style: const TextStyle(color: AppColors.notrGri400, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    final bool isLoading = widget.authProvider.state.isLoading;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleLogin,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Giris Yap', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildLinks() {
    return Column(
      children: [
        TextButton(
          onPressed: _navigateToPasswordReset,
          child: const Text('Sifremi Unuttum'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Hesabiniz yok mu?',
              style: TextStyle(color: AppColors.notrGri500),
            ),
            TextButton(
              onPressed: _navigateToRegister,
              child: const Text('Kayit Ol'),
            ),
          ],
        ),
      ],
    );
  }
}
