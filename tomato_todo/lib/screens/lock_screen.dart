// screens/lock_screen.dart - 应用锁
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/backgrounds.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String? _error;

  void _tap(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 130), _verify);
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _verify() {
    if (!mounted) return;
    final sp = context.read<SettingsProvider>();
    if (sp.settings.pinHash == null) {
      // 无有效密码(异常数据)时直接放行
      widget.onUnlocked();
      return;
    }
    final ok = sp.verifyPin(_pin);
    if (ok) {
      widget.onUnlocked();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _error = '密码错误, 请重试';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.background,
              theme.primary.withOpacity(0.22),
              theme.background,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline,
                    size: 34, color: theme.primary),
              ),
              const SizedBox(height: 18),
              Text('时光秘书',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: theme.foreground)),
              const SizedBox(height: 6),
              Text('请输入 4 位数字密码',
                  style: TextStyle(fontSize: 12, color: theme.muted)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: filled ? theme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: filled
                            ? theme.primary
                            : theme.foreground.withOpacity(0.22),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(
                height: 34,
                child: Center(
                  child: Text(
                    _error ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFFF5252)),
                  ),
                ),
              ),
              const Spacer(),
              _Keypad(
                theme: theme,
                onDigit: _tap,
                onBackspace: _backspace,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 13, color: theme.muted),
                    const SizedBox(width: 4),
                    Text('数据仅保存在本机, 仅你可访问',
                        style: TextStyle(fontSize: 10, color: theme.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ThemeDef theme;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _Keypad({
    required this.theme,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 14,
        children: keys.map((k) {
          if (k.isEmpty) {
            return const SizedBox(width: 64, height: 64);
          }
          final isDelete = k == '⌫';
          return GestureDetector(
            onTap: () => isDelete ? onBackspace() : onDigit(k),
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.cardBackground.withOpacity(0.6),
                shape: BoxShape.circle,
                border: Border.all(
                    color: theme.foreground.withOpacity(0.06)),
              ),
              child: isDelete
                  ? Icon(Icons.backspace_outlined,
                      size: 20, color: theme.foreground.withOpacity(0.7))
                  : Text(
                      k,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: theme.foreground),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
