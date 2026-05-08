import 'package:flutter/material.dart';

class MainMenuScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onLoadGame;
  final VoidCallback onOpenLeaderboard;
  final VoidCallback? onExit;
  final VoidCallback? onUserInteraction;

  const MainMenuScreen({
    super.key,
    required this.onStart,
    required this.onLoadGame,
    required this.onOpenLeaderboard,
    this.onExit,
    this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF35D8FF);
    const neonBlue = Color(0xFF1E6BFF);
    const panelBg = Color(0xCC0A1324);

    final newGameStyle =
        ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF102746),
          foregroundColor: neonCyan,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: const BorderSide(color: neonCyan, width: 1.2),
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return neonCyan.withValues(alpha: 0.22);
            }
            if (states.contains(WidgetState.hovered)) {
              return neonCyan.withValues(alpha: 0.12);
            }
            return null;
          }),
        );

    final panelButtonStyle =
        OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: neonCyan.withValues(alpha: 0.85), width: 1.0),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return neonCyan.withValues(alpha: 0.18);
            }
            if (states.contains(WidgetState.hovered)) {
              return neonCyan.withValues(alpha: 0.10);
            }
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              // Keep disabled Load Game readable but still visually inactive.
              return const Color(0xFFA7E9FF);
            }
            return Colors.white;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: neonCyan.withValues(alpha: 0.55),
                width: 1.0,
              );
            }
            return BorderSide(
              color: neonCyan.withValues(alpha: 0.85),
              width: 1.0,
            );
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0x55133046);
            }
            return const Color(0x33133046);
          }),
        );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onUserInteraction?.call(),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/sprites/world/back_menu.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.20),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VOID RELAY',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: Color(0xFFE3F8FF),
                        fontSize: 50,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        shadows: [
                          Shadow(color: neonBlue, blurRadius: 18),
                          Shadow(color: neonCyan, blurRadius: 36),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'MVP Build',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: Color(0xFF9ED9FF),
                        fontSize: 14,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 290,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: neonCyan.withValues(alpha: 0.85),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: neonBlue.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'MENU',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              color: Color(0xFFA6EBFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            style: newGameStyle,
                            onPressed: () {
                              onUserInteraction?.call();
                              onStart();
                            },
                            child: const Text('New Game'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            style: panelButtonStyle,
                            onPressed: () {
                              onUserInteraction?.call();
                              onLoadGame();
                            },
                            child: const Text('Load Game'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            style: panelButtonStyle,
                            onPressed: () {
                              onUserInteraction?.call();
                              onOpenLeaderboard();
                            },
                            child: const Text('Leaderboard'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            style: panelButtonStyle,
                            onPressed: onExit == null
                                ? null
                                : () {
                                    onUserInteraction?.call();
                                    onExit!.call();
                                  },
                            child: const Text('Exit'),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Select New Game to begin',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              color: Color(0xFF82B4CE),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
