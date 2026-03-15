import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const LoginPage({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _registerMode = false;
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      bool ok;
      if (_registerMode) {
        ok = await AuthService.instance.register(
          email: _emailController.text,
          username: _usernameController.text,
          password: _passwordController.text,
        );
      } else {
        ok = await AuthService.instance.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) {
        return;
      }
      if (ok) {
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorText = 'Giris basarisiz oldu. Bilgileri kontrol edin.';
        });
      }
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      String backendError = (e.response?.data is Map)
          ? ((e.response?.data['detail'] ?? e.message).toString())
          : (e.message ?? 'Sunucu hatasi');
      setState(() {
        _errorText = backendError;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Beklenmeyen bir hata oldu.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: Colors.grey.shade900,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _registerMode ? 'Kayit Ol' : 'Giris Yap',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (_registerMode) const SizedBox(height: 12),
                  if (_registerMode)
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Kullanici Adi',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Sifre',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (_errorText != null) const SizedBox(height: 12),
                  if (_errorText != null)
                    Text(
                      _errorText!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(
                        _loading
                            ? 'Isleniyor...'
                            : (_registerMode ? 'Kayit Ol' : 'Giris Yap'),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _registerMode = !_registerMode;
                              _errorText = null;
                            });
                          },
                    child: Text(
                      _registerMode
                          ? 'Zaten hesabin var mi? Giris yap'
                          : 'Hesabin yok mu? Kayit ol',
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
