import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_settings_model.dart';
import '../../services/firestore_service.dart';
import '../theme.dart';

/// Modal dialog for configuring GitHub Access Token, Gemini API Key, and Monitored Repositories.
class SettingsDialog extends StatefulWidget {
  final String uid;

  const SettingsDialog({super.key, required this.uid});

  static Future<void> show(BuildContext context, String uid) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SettingsDialog(uid: uid),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final _newRepoController = TextEditingController();

  List<String> _monitoredRepos = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureToken = true;
  bool _obscureGeminiKey = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final firestoreService = context.read<FirestoreService>();
      final settings = await firestoreService.getUserSettings(widget.uid);
      if (mounted) {
        setState(() {
          _tokenController.text = settings.githubAccessToken ?? '';
          _geminiKeyController.text = settings.geminiApiKey ?? '';
          _monitoredRepos = List<String>.from(settings.monitoredRepos);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _geminiKeyController.dispose();
    _newRepoController.dispose();
    super.dispose();
  }

  void _addRepo() {
    final text = _newRepoController.text.trim();
    if (text.isEmpty) return;
    if (!_monitoredRepos.contains(text)) {
      setState(() {
        _monitoredRepos.add(text);
        _newRepoController.clear();
      });
    }
  }

  void _removeRepo(String repo) {
    setState(() {
      _monitoredRepos.remove(repo);
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final firestoreService = context.read<FirestoreService>();
      final updatedSettings = UserSettingsModel(
        uid: widget.uid,
        githubAccessToken: _tokenController.text.trim().isEmpty ? null : _tokenController.text.trim(),
        geminiApiKey: _geminiKeyController.text.trim().isEmpty ? null : _geminiKeyController.text.trim(),
        monitoredRepos: _monitoredRepos,
      );

      await firestoreService.updateUserSettings(widget.uid, updatedSettings);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppTheme.dotRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.settings_outlined, color: AppTheme.textPrimary, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'User Settings',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: AppTheme.textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure your API keys and monitored repositories. These are stored directly in your Firestore user profile.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // GitHub Personal Access Token
                            Text(
                              'GitHub Personal Access Token',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Classic token or fine-grained token with repo & read:user scopes.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _tokenController,
                              obscureText: _obscureToken,
                              decoration: InputDecoration(
                                hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                                prefixIcon: const Icon(Icons.key_outlined, size: 18, color: AppTheme.textMuted),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureToken ? Icons.visibility_off : Icons.visibility,
                                    size: 18,
                                    color: AppTheme.textMuted,
                                  ),
                                  onPressed: () => setState(() => _obscureToken = !_obscureToken),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Gemini API Key
                            Text(
                              'Gemini API Key',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Used by Pydantic AI in Cloud Functions to prioritize issues.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _geminiKeyController,
                              obscureText: _obscureGeminiKey,
                              decoration: InputDecoration(
                                hintText: 'AIzaSy...',
                                prefixIcon: const Icon(Icons.auto_awesome_outlined, size: 18, color: AppTheme.textMuted),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureGeminiKey ? Icons.visibility_off : Icons.visibility,
                                    size: 18,
                                    color: AppTheme.textMuted,
                                  ),
                                  onPressed: () => setState(() => _obscureGeminiKey = !_obscureGeminiKey),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Monitored Repositories
                            Text(
                              'Monitored Repositories',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Repositories to synchronize tasks from (e.g. "owner/repo").',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _newRepoController,
                              decoration: const InputDecoration(
                                hintText: 'e.g. google/flutter (press Enter to add)',
                                prefixIcon: Icon(Icons.book_outlined, size: 18, color: AppTheme.textMuted),
                              ),
                              onFieldSubmitted: (_) => _addRepo(),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _monitoredRepos.isEmpty
                                  ? [
                                      Text(
                                        'No monitored repositories added yet.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: AppTheme.textPlaceholder,
                                        ),
                                      ),
                                    ]
                                  : _monitoredRepos.map((repo) {
                                      return Chip(
                                        label: Text(
                                          repo,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        avatar: const Icon(Icons.folder_outlined, size: 14, color: AppTheme.textMuted),
                                        deleteIcon: const Icon(Icons.close, size: 14),
                                        onDeleted: () => _removeRepo(repo),
                                        backgroundColor: const Color(0xFFF3F4F6),
                                        side: const BorderSide(color: AppTheme.borderSubtle),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      );
                                    }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: const BorderSide(color: AppTheme.borderMedium),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
