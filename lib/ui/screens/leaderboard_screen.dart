import 'package:flutter/material.dart';

import '../../systems/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.onBack, this.onUiClick});

  final VoidCallback onBack;
  final VoidCallback? onUiClick;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = LeaderboardService.listEntries(limit: 20);
  }

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF35D8FF);
    const neonBlue = Color(0xFF1E6BFF);

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
          child: Container(color: Colors.black.withValues(alpha: 0.62)),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
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
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            widget.onUiClick?.call();
                            widget.onBack();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFBDF4FF),
                            side: BorderSide(
                              color: neonCyan.withValues(alpha: 0.85),
                            ),
                          ),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'LEADERBOARD',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            color: Color(0xFFE3F8FF),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0x5535D8FF)),
                  Expanded(
                    child: FutureBuilder<List<LeaderboardEntry>>(
                      future: _entriesFuture,
                      builder: (context, snapshot) {
                        final entries = snapshot.data;
                        if (entries == null) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (entries.isEmpty) {
                          return const Center(
                            child: Text(
                              'No records yet',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                color: Color(0xFFA7E9FF),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final e = entries[index];
                            final dt = DateTime.tryParse(
                              e.savedAtIso,
                            )?.toLocal();
                            final dateText = dt == null
                                ? e.savedAtIso
                                : '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x99101828),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: neonCyan.withValues(alpha: 0.60),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(
                                        fontFamily: 'Orbitron',
                                        color: Color(0xFFBDF4FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Score ${e.score} | Level ${e.level}',
                                      style: const TextStyle(
                                        fontFamily: 'Orbitron',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    dateText,
                                    style: const TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontSize: 11,
                                      color: Color(0xFFA7E9FF),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
