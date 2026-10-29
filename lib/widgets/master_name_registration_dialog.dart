import 'package:flutter/material.dart';

/// 入力を残したまま再試行でき、Firestoreの登録成功後にだけ選択へ進む。
class MasterNameRegistrationDialog extends StatefulWidget {
  const MasterNameRegistrationDialog({
    super.key,
    required this.label,
    required this.onRegister,
    this.initialName = '',
    this.companyName,
  });

  final String label;
  final String initialName;
  final String? companyName;
  final Future<Map<String, String>> Function(String) onRegister;

  @override
  State<MasterNameRegistrationDialog> createState() =>
      _MasterNameRegistrationDialogState();
}

class _MasterNameRegistrationDialogState
    extends State<MasterNameRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.onRegister(_controller.text.trim());
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '登録できませんでした。通信状態や会社情報を確認して、もう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text('${widget.label}を追加'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.companyName != null) ...[
                Text('所属会社：${widget.companyName}'),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _controller,
                autofocus: true,
                enabled: !_saving,
                decoration: InputDecoration(labelText: widget.label),
                textInputAction: TextInputAction.done,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? '${widget.label}を入力してください'
                    : null,
                onFieldSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 12),
              const Text('登録した名前は次回から一覧で選択できます。'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _register,
          child: Text(_saving ? '登録中…' : '登録して選択'),
        ),
      ],
    ),
  );
}
