import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

/// Sifre Sifirlama Sayfasi
class SifreSifirlamaSayfasi extends StatefulWidget {
  final AuthProvider authProvider;

  const SifreSifirlamaSayfasi({
    super.key,
    required this.authProvider,
  });

  @override
  State<SifreSifirlamaSayfasi> createState() => _SifreSifirlamaSayfasiState();
}

class _SifreSifirlamaSayfasiState extends State<SifreSifirlamaSayfasi> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isEmailSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });
    final bool success = await widget.authProvider.sendPasswordResetEmail(
      _emailController.text.trim(),
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isEmailSent = success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sifre Sifirlama'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _isEmailSent ? _buildSuccessContent() : _buildFormContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: AppColors.kartEnerjiUretim,
        ),
        const SizedBox(height: 24),
        const Text(
          'E-posta Gonderildi',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          '${_emailController.text} adresine sifre sifirlama baglantisi gonderildi.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.notrGri400),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Giris Sayfasina Don'),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_reset,
            size: 64,
            color: AppColors.gridMor,
          ),
          const SizedBox(height: 24),
          const Text(
            'Sifreni Sifirla',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'E-posta adresinizi girin, size sifre sifirlama baglantisi gonderelim.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.notrGri400),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleReset,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sifirlama Baglantisi Gonder', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
