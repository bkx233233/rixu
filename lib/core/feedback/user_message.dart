import 'package:supabase_flutter/supabase_flutter.dart';

String toChineseError(Object error, {String fallback = '操作失败，请稍后重试。'}) {
  final raw = error is AuthException ? error.message : error.toString();
  final message = raw.trim();
  final lower = message.toLowerCase();

  if (message.isEmpty) return fallback;
  if (message.contains('邮箱或密码') ||
      lower.contains('invalid login credentials')) {
    return '邮箱或密码错误，请检查后重试。';
  }
  if (lower.contains('email not confirmed')) return '邮箱尚未确认，请先完成邮箱确认。';
  if (lower.contains('user already registered')) return '该邮箱已经注册，请直接登录。';
  if (lower.contains('invalid email') || lower.contains('email address'))
    return '邮箱格式不正确。';
  if (lower.contains('password')) return '密码不符合要求，请重新设置。';
  if (lower.contains('network') ||
      lower.contains('fetch') ||
      lower.contains('socket')) {
    return '网络连接失败，请检查网络后重试。';
  }
  if (lower.contains('row-level security') ||
      lower.contains('permission denied')) {
    return '没有权限执行此操作，请重新登录。';
  }
  if (lower.contains('relation') && lower.contains('does not exist')) {
    return '云端数据表尚未初始化，请检查数据库迁移。';
  }
  if (lower.contains('column') && lower.contains('does not exist')) {
    return '云端数据版本未更新，请执行最新数据库迁移。';
  }
  if (lower.contains('foreign key')) {
    return '账号资料尚未初始化，请重新登录后重试。';
  }
  if (lower.contains('check constraint') || lower.contains('invalid input')) {
    return '填写的数据格式不正确，请检查后重试。';
  }
  if (lower.contains('ambiguous')) {
    return '云端训练校验函数版本异常，请重新执行训练数据库迁移。';
  }
  if (lower.contains('duplicate key')) return '这条记录已经存在。';
  if (message.contains('休息中不能')) return message;
  if (message.contains('失败') || message.contains('错误') || message.contains('请'))
    return message;
  return fallback;
}
