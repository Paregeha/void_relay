import 'dart:convert';

import 'package:flutter/material.dart';

import '../../systems/save_game_service.dart';

enum SaveSlotsMode { save, load }

class LoadGameScreen extends StatefulWidget {
  const LoadGameScreen({
    super.key,
    required this.mode,
    required this.onBack,
    this.onLoad,
    this.onSave,
    this.onUiClick,
    this.modal = false,
  }) : assert(
         (mode == SaveSlotsMode.load && onLoad != null) ||
             (mode == SaveSlotsMode.save && onSave != null),
         'Provide onLoad for load mode or onSave for save mode',
       );

  final SaveSlotsMode mode;
  final VoidCallback onBack;
  final Future<void> Function(String saveId)? onLoad;
  final Future<bool> Function(String saveId)? onSave;
  final VoidCallback? onUiClick;
  final bool modal;

  @override
  State<LoadGameScreen> createState() => _LoadGameScreenState();
}

class _LoadGameScreenState extends State<LoadGameScreen> {
  late Future<List<SaveSlotEntry>> _slotsFuture;
  String? _busySlotId;

  static const Color _neonCyan = Color(0xFF35D8FF);
  static const Color _neonBlue = Color(0xFF1E6BFF);

  ButtonStyle _backButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFBDF4FF),
      side: BorderSide(color: _neonCyan.withValues(alpha: 0.85)),
      backgroundColor: const Color(0x6603111F),
      textStyle: const TextStyle(
        fontFamily: 'Orbitron',
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  ButtonStyle _slotActionButtonStyle() {
    return ElevatedButton.styleFrom(
      foregroundColor: const Color(0xFFE9FAFF),
      backgroundColor: const Color(0xFF08304D),
      disabledForegroundColor: const Color(0xFF6D8EA0),
      disabledBackgroundColor: const Color(0x33243E52),
      textStyle: const TextStyle(
        fontFamily: 'Orbitron',
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      minimumSize: const Size(96, 40),
      side: BorderSide(color: _neonCyan.withValues(alpha: 0.8), width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
      shadowColor: _neonBlue.withValues(alpha: 0.45),
    );
  }

  ButtonStyle _dialogButtonStyle({required bool primary}) {
    return ElevatedButton.styleFrom(
      foregroundColor: primary
          ? const Color(0xFFE9FAFF)
          : const Color(0xFF9FD5EA),
      backgroundColor: primary
          ? const Color(0xFF0A3A63)
          : const Color(0x66203345),
      textStyle: const TextStyle(
        fontFamily: 'Orbitron',
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: _neonCyan.withValues(alpha: primary ? 0.95 : 0.55),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    );
  }

  @override
  void initState() {
    super.initState();
    _slotsFuture = SaveGameService.listSlots();
  }

  Future<void> _reload() async {
    setState(() {
      _slotsFuture = SaveGameService.listSlots();
    });
  }

  Future<bool> _confirmOverwrite(String slotLabel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A1324),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _neonCyan.withValues(alpha: 0.8)),
          ),
          shadowColor: _neonBlue.withValues(alpha: 0.4),
          title: const Text(
            'Overwrite this save?',
            style: TextStyle(fontFamily: 'Orbitron', color: Color(0xFFE3F8FF)),
          ),
          content: Text(
            '$slotLabel already contains data.',
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Color(0xFFA7E9FF),
            ),
          ),
          actions: [
            ElevatedButton(
              style: _dialogButtonStyle(primary: false),
              onPressed: () {
                widget.onUiClick?.call();
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(fontFamily: 'Orbitron'),
              ),
            ),
            ElevatedButton(
              style: _dialogButtonStyle(primary: true),
              onPressed: () {
                widget.onUiClick?.call();
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Overwrite',
                style: TextStyle(fontFamily: 'Orbitron'),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  String _formatSavedAt(SaveGameData? save) {
    if (save == null) return 'Empty Slot';
    final savedAt = save.savedAt?.toLocal();
    if (savedAt == null) return save.savedAtIso;
    final y = savedAt.year.toString().padLeft(4, '0');
    final m = savedAt.month.toString().padLeft(2, '0');
    final d = savedAt.day.toString().padLeft(2, '0');
    final hh = savedAt.hour.toString().padLeft(2, '0');
    final mm = savedAt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _handleSaveSlotTap(SaveSlotEntry slot) async {
    if (_busySlotId != null) return;
    widget.onUiClick?.call();
    if (slot.hasSave) {
      final allow = await _confirmOverwrite(slot.slotLabel);
      if (!allow) return;
    }

    setState(() => _busySlotId = slot.slotId);
    try {
      final ok = await widget.onSave!(slot.slotId);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game Saved'),
            duration: Duration(milliseconds: 1300),
          ),
        );
        widget.onBack();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Save failed: ${SaveGameService.lastSaveError ?? 'unknown error'}',
          ),
          duration: const Duration(milliseconds: 1900),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          duration: const Duration(milliseconds: 1700),
        ),
      );
      await _reload();
    } finally {
      if (mounted) {
        setState(() => _busySlotId = null);
      }
    }
  }

  Future<void> _handleLoadSlotTap(SaveSlotEntry slot) async {
    if (_busySlotId != null || !slot.hasSave) return;
    widget.onUiClick?.call();
    setState(() => _busySlotId = slot.slotId);
    try {
      await widget.onLoad!(slot.slotId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Load failed: $e'),
          duration: const Duration(milliseconds: 1700),
        ),
      );
      await _reload();
    } finally {
      if (mounted) {
        setState(() => _busySlotId = null);
      }
    }
  }

  Widget _buildSlotsList() {
    const neonCyan = Color(0xFF35D8FF);

    return FutureBuilder<List<SaveSlotEntry>>(
      future: _slotsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final slots = snapshot.data!;
        return ListView.separated(
          itemCount: slots.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final slot = slots[index];
            final save = slot.data;
            final isBusy = _busySlotId == slot.slotId;
            final canTap =
                !isBusy && (widget.mode == SaveSlotsMode.save || slot.hasSave);

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: !canTap
                  ? null
                  : () {
                      if (widget.mode == SaveSlotsMode.save) {
                        _handleSaveSlotTap(slot);
                      } else {
                        _handleLoadSlotTap(slot);
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: canTap
                      ? const Color(0xCC03111F)
                      : const Color(0x99101828),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: neonCyan.withValues(alpha: canTap ? 0.75 : 0.34),
                  ),
                ),
                child: Row(
                  children: [
                    _SaveThumb(base64Data: save?.thumbnailBase64),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.slotLabel,
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              color: Color(0xFFBDF4FF),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            save == null
                                ? 'Empty Slot'
                                : 'Level: ${save.levelId}',
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            save == null
                                ? '-'
                                : 'HP: ${save.playerHp}/${save.playerMaxHp}',
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            save == null ? '-' : 'Score: ${save.score}',
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            save == null
                                ? '-'
                                : 'Weapon: ${save.currentWeapon}',
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatSavedAt(save),
                            style: const TextStyle(
                              fontFamily: 'Orbitron',
                              color: Color(0xFF82B4CE),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: _slotActionButtonStyle(),
                      onPressed: !canTap
                          ? null
                          : () {
                              if (widget.mode == SaveSlotsMode.save) {
                                _handleSaveSlotTap(slot);
                              } else {
                                _handleLoadSlotTap(slot);
                              }
                            },
                      child: Text(
                        widget.mode == SaveSlotsMode.save
                            ? isBusy
                                  ? 'Saving...'
                                  : slot.hasSave
                                  ? 'Overwrite'
                                  : 'Save'
                            : isBusy
                            ? 'Loading...'
                            : 'Load',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPanelScaffold() {
    final title = widget.mode == SaveSlotsMode.save
        ? 'SAVE SLOT SELECTION'
        : 'LOAD GAME';

    return Container(
      constraints: const BoxConstraints(maxWidth: 980),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xCC03111F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neonCyan.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: _neonBlue.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton(
                style: _backButtonStyle(),
                onPressed: () {
                  widget.onUiClick?.call();
                  widget.onBack();
                },
                child: Text(
                  widget.mode == SaveSlotsMode.save ? 'Cancel' : 'Back',
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: Color(0xFFE3F8FF),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  shadows: [
                    Shadow(color: _neonBlue, blurRadius: 12),
                    Shadow(color: _neonCyan, blurRadius: 22),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildSlotsList()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.modal) {
      return Container(
        color: Colors.black.withValues(alpha: 0.62),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Center(child: _buildPanelScaffold()),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/sprites/world/back_menu.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildPanelScaffold(),
          ),
        ),
      ],
    );
  }
}

class _SaveThumb extends StatelessWidget {
  const _SaveThumb({required this.base64Data});

  final String? base64Data;

  @override
  Widget build(BuildContext context) {
    final raw = base64Data;
    if (raw == null || raw.isEmpty) {
      return _placeholder();
    }

    try {
      final bytes = base64Decode(raw);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(bytes, width: 110, height: 62, fit: BoxFit.cover),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() {
    return Container(
      width: 110,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0x55133046),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x8835D8FF), width: 1.4),
      ),
      alignment: Alignment.center,
      child: const Text(
        'NO SIGNAL',
        style: TextStyle(
          fontFamily: 'Orbitron',
          color: Color(0xFFA7E9FF),
          fontSize: 11,
        ),
      ),
    );
  }
}
