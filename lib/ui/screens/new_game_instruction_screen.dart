import 'package:flutter/material.dart';

class NewGameInstructionScreen extends StatelessWidget {
  final VoidCallback onClose;

  const NewGameInstructionScreen({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF35D8FF);
    const neonBlue = Color(0xFF1E6BFF);
    const panelBg = Color(0xE60A1324);

    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1060, maxHeight: 760),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: neonCyan.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: neonBlue.withValues(alpha: 0.34),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              const _SectionTitle(
                title: 'MISSION BRIEFING',
                subtitle: 'Survive. Eliminate hostiles. Reach the exit.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _BriefingCard(
                        width: 480,
                        title: 'CONTROLS',
                        child: const Column(
                          children: [
                            _ControlRow(
                              keys: ['A', 'D', 'Left', 'Right'],
                              label: 'Movement',
                            ),
                            SizedBox(height: 10),
                            _ControlRow(keys: ['Space'], label: 'Jump'),
                            SizedBox(height: 10),
                            _ControlRow(keys: ['F'], label: 'Fire weapon'),
                            SizedBox(height: 10),
                            _ControlRow(keys: ['E'], label: 'Interact'),
                            SizedBox(height: 10),
                            _ControlRow(
                              keys: ['C', 'X', '1', '2'],
                              label: 'Switch weapon',
                            ),
                          ],
                        ),
                      ),
                      _BriefingCard(
                        width: 480,
                        title: 'WEAPONS',
                        child: const Column(
                          children: [
                            _InfoRow(
                              title: 'Primary Blaster',
                              description:
                                  'Reliable rapid-fire weapon for close and mid-range combat.',
                            ),
                            SizedBox(height: 10),
                            _InfoRow(
                              title: 'Heavy Blaster',
                              description:
                                  'Stronger shots with slower rhythm and higher heat cost.',
                            ),
                            SizedBox(height: 10),
                            _InfoRow(
                              title: 'Fire Discipline',
                              description:
                                  'Manage your fire rate to avoid reactor overheating.',
                            ),
                          ],
                        ),
                      ),
                      _BriefingCard(
                        width: 480,
                        title: 'REACTOR CORE',
                        child: const Column(
                          children: [
                            _InfoRow(
                              title: 'Core Heat',
                              description:
                                  'Continuous fire increases heat and can lock weapons for a short time.',
                            ),
                            SizedBox(height: 10),
                            _InfoRow(
                              title: 'Cooling Cells',
                              description:
                                  'Cooling pickups reduce heat instantly and keep weapons online.',
                            ),
                          ],
                        ),
                      ),
                      _BriefingCard(
                        width: 480,
                        title: 'ENEMIES & SCORE',
                        child: const Column(
                          children: [
                            _EnemyScoreRow(
                              enemy: 'Ground Hostile',
                              score: '+1 SCORE',
                              description:
                                  'Patrols platforms and attacks on sight.',
                            ),
                            SizedBox(height: 10),
                            _EnemyScoreRow(
                              enemy: 'Drone Unit',
                              score: '+2 SCORE',
                              description:
                                  'Flying enemy that keeps distance and shoots.',
                            ),
                            SizedBox(height: 10),
                            _EnemyScoreRow(
                              enemy: 'Sentry Turret',
                              score: '+3 SCORE',
                              description:
                                  'Stationary threat with higher reward.',
                            ),
                          ],
                        ),
                      ),
                      _BriefingCard(
                        width: 480,
                        title: 'PICKUPS',
                        child: const Column(
                          children: [
                            _InfoRow(
                              title: 'Red Heart',
                              description:
                                  'Restores player health up to maximum HP.',
                              accentColor: Color(0xFFFF5A7A),
                            ),
                            SizedBox(height: 10),
                            _InfoRow(
                              title: 'Cooling Cell',
                              description:
                                  'Reduces reactor heat and keeps your weapon online.',
                              accentColor: Color(0xFF63E0FF),
                            ),
                          ],
                        ),
                      ),
                      _BriefingCard(
                        width: 480,
                        title: 'EVENTS & HAZARDS',
                        child: const Column(
                          children: [
                            _InfoRow(
                              title: 'Exit Door',
                              description:
                                  'Destroy all enemies to unlock the exit. Enter the opened door to claim the Sector Reward.',
                            ),
                            SizedBox(height: 10),
                            _InfoRow(
                              title: 'Toxic Gas',
                              description:
                                  'Dangerous environmental event. Stay out of the green zone.',
                            ),
                            SizedBox(height: 10),
                            _InfoRow(
                              title: 'Mission Flow',
                              description:
                                  'Pickups spawn during the mission at random valid locations.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF12365F),
                      foregroundColor: neonCyan,
                      side: const BorderSide(color: neonCyan, width: 1.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Start Mission'),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            color: Color(0xFFCCF4FF),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            color: Color(0xFF9ED9FF),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _BriefingCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double width;

  const _BriefingCard({
    required this.title,
    required this.child,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x80203B67),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF35D8FF).withValues(alpha: 0.65),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Orbitron',
                color: Color(0xFFB7EEFF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  final List<String> keys;
  final String label;

  const _ControlRow({required this.keys, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keys.map((k) => _KeyCap(k)).toList(growable: false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Color(0xFFD8ECFF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyCap extends StatelessWidget {
  final String text;

  const _KeyCap(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0E233E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4CDFFF), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E6BFF).withValues(alpha: 0.35),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Orbitron',
          color: Color(0xFFE7FAFF),
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String description;
  final Color accentColor;

  const _InfoRow({
    required this.title,
    required this.description,
    this.accentColor = const Color(0xFF35D8FF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x4013264A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Color(0xFFD8ECFF),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnemyScoreRow extends StatelessWidget {
  final String enemy;
  final String score;
  final String description;

  const _EnemyScoreRow({
    required this.enemy,
    required this.score,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x4013264A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF35D8FF).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  enemy,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    color: Color(0xFFE7FAFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ScoreBadge(score),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Color(0xFFD8ECFF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String text;

  const _ScoreBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF102A48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF35D8FF), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Orbitron',
          color: Color(0xFF8EEEFF),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
