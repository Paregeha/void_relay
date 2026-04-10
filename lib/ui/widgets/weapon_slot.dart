import 'package:flutter/material.dart';

class WeaponSlot extends StatelessWidget {
  final String activeWeaponName;
  final int activeWeaponSlot;
  final String secondaryWeaponName;
  final int? secondaryWeaponSlot;

  const WeaponSlot({
    super.key,
    required this.activeWeaponName,
    required this.activeWeaponSlot,
    required this.secondaryWeaponName,
    required this.secondaryWeaponSlot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Active [$activeWeaponSlot]: $activeWeaponName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            secondaryWeaponSlot == null
                ? 'Secondary: -'
                : 'Secondary [$secondaryWeaponSlot]: $secondaryWeaponName',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 4),
          const Text(
            'Switch: C/X or 1/2',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
