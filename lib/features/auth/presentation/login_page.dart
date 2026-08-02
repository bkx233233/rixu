import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/feedback/user_message.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _message;
  String? _messageTitle;
  bool _messageIsError = false;
  bool _showResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final isRegistering = _isRegistering;
    final failureTitle = isRegistering ? '注册失败' : '登录失败';
    final failureFallback =
        isRegistering ? '注册失败，请检查填写内容和网络后重试。' : '登录失败，请检查邮箱、密码和邮箱确认状态后重试。';

    setState(() {
      _isSubmitting = true;
      _message = null;
      _messageTitle = null;
      _messageIsError = false;
      _showResend = false;
    });

    try {
      if (isRegistering) {
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'display_name': _nameController.text.trim()},
        ).timeout(const Duration(seconds: 15));
        if (!mounted) {
          return;
        }
        final needsConfirmation = response.session == null;
        _setSuccess(
          title: '注册成功',
          message: needsConfirmation ? '确认邮件已发送，请完成邮箱确认后登录。' : '账号已创建，可以开始使用。',
          showResend: needsConfirmation,
        );
      } else {
        await Supabase.instance.client.auth
            .signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
            .timeout(const Duration(seconds: 15));
        if (mounted) {
          _setSuccess(title: '登录成功', message: '正在进入日序。');
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        _setError(
            failureTitle, toChineseError(error, fallback: failureFallback));
      }
    } on TimeoutException {
      if (mounted) {
        _setError('连接超时', '请求超过 15 秒没有响应，请检查网络后重试。');
      }
    } catch (error) {
      if (mounted) {
        _setError(
            failureTitle, toChineseError(error, fallback: failureFallback));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _setSuccess(
      {required String title,
      required String message,
      bool showResend = false}) {
    setState(() {
      _messageTitle = title;
      _message = message;
      _messageIsError = false;
      _showResend = showResend;
    });
    _showFeedback('$title：$message', isError: false);
  }

  void _setError(String title, String message) {
    setState(() {
      _messageTitle = title;
      _message = message;
      _messageIsError = true;
      _showResend = false;
    });
    _showFeedback(message, isError: true);
  }

  Future<void> _resendConfirmation() async {
    setState(() => _isResending = true);
    try {
      await Supabase.instance.client.auth
          .resend(
            type: OtpType.signup,
            email: _emailController.text.trim(),
          )
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        _setSuccess(title: '邮件已重新发送', message: '请查收邮箱后完成确认。', showResend: true);
      }
    } on AuthException catch (error) {
      if (mounted)
        _setError('发送失败', toChineseError(error, fallback: '确认邮件发送失败，请稍后重试。'));
    } on TimeoutException {
      if (mounted) _setError('连接超时', '邮件发送超过 15 秒没有响应，请稍后重试。');
    } catch (error) {
      if (mounted)
        _setError('发送失败', toChineseError(error, fallback: '确认邮件发送失败，请稍后重试。'));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showFeedback(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('日序', style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 8),
                    Text(_isRegistering ? '创建你的云端账号' : '登录后同步你的日程与健康记录'),
                    const SizedBox(height: 24),
                    if (_isRegistering) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: '昵称'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? '请输入昵称。'
                                : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: '邮箱'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value != null && value.contains('@')
                          ? null
                          : '请输入有效邮箱。',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: '密码'),
                      obscureText: true,
                      validator: (value) => value != null && value.length >= 8
                          ? null
                          : '密码至少需要 8 位。',
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_messageIsError
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .primaryContainer)
                              .withValues(alpha: 0.9),
                          border: Border.all(
                            color: _messageIsError
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _messageIsError
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color: _messageIsError
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_messageTitle ?? '提示',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(_message!),
                                  if (_showResend) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        TextButton(
                                          onPressed: _isResending
                                              ? null
                                              : _resendConfirmation,
                                          child: Text(_isResending
                                              ? '正在发送…'
                                              : '重新发送确认邮件'),
                                        ),
                                        TextButton(
                                          onPressed: _isSubmitting
                                              ? null
                                              : () => setState(() {
                                                    _isRegistering = false;
                                                    _message = null;
                                                    _messageTitle = null;
                                                    _showResend = false;
                                                  }),
                                          child: const Text('去登录'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isRegistering ? '注册' : '登录'),
                    ),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                                _isRegistering = !_isRegistering;
                                _message = null;
                                _messageTitle = null;
                                _messageIsError = false;
                                _showResend = false;
                              }),
                      child: Text(_isRegistering ? '已有账号，去登录' : '没有账号，去注册'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
