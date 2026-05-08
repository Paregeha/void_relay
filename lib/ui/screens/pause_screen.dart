import 'package:flutter/material.dart';

class PauseScreen extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback? onSave;
  final VoidCallback onMenu;
  final VoidCallback? onExit;

  const PauseScreen({
    super.key,
    required this.onResume,
    this.onSave,
    required this.onMenu,
    this.onExit,
  });

  @override
  State<PauseScreen> createState() => _PauseScreenState();
}

class _PauseScreenState extends State<PauseScreen> {
  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF00D9FF);
    const neonBlue = Color(0xFF1E6BFF);

    final panelButtonStyle =
        OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFBDF4FF),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: BorderSide(color: neonCyan.withValues(alpha: 0.85)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: const Color(0x33133046),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return neonCyan.withValues(alpha: 0.2);
            }
            if (states.contains(WidgetState.hovered)) {
              return neonCyan.withValues(alpha: 0.1);
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFF77ABC0);
            }
            return const Color(0xFFBDF4FF);
          }),
        );

    return Container(
      color: Colors.black.withValues(alpha: 0.58),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xCC03111F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: neonCyan.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: neonBlue.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSED',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: Color(0xFF7DF9FF),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(color: neonBlue, blurRadius: 14),
                    Shadow(color: neonCyan, blurRadius: 26),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: panelButtonStyle,
                  onPressed: widget.onResume,
                  child: const Text('Resume'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: panelButtonStyle,
                  onPressed: widget.onSave,
                  child: const Text('Save Game'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: panelButtonStyle,
                  onPressed: widget.onMenu,
                  child: const Text('Menu'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: panelButtonStyle,
                  onPressed: widget.onExit,
                  child: const Text('Exit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
