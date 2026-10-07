import 'package:flutter/material.dart';
import 'package:business_app/core/sync/sync_engine.dart';

class SyncStatusBadge extends StatelessWidget {
  final SyncEngine syncEngine;

  const SyncStatusBadge({super.key, required this.syncEngine});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncEngineStatus>(
      stream: syncEngine.statusStream,
      initialData: SyncEngineStatus.idle,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncEngineStatus.idle;

        IconData icon;
        Color color;
        String label;

        switch (status) {
          case SyncEngineStatus.syncing:
            icon = Icons.sync_rounded;
            color = const Color(0xFF3B82F6);
            label = 'Syncing...';
            break;
          case SyncEngineStatus.offline:
            icon = Icons.cloud_off_rounded;
            color = const Color(0xFFF59E0B);
            label = 'Offline Mode';
            break;
          case SyncEngineStatus.error:
            icon = Icons.sync_problem_rounded;
            color = const Color(0xFFEF4444);
            label = 'Sync Retrying';
            break;
          case SyncEngineStatus.idle:
            icon = Icons.cloud_done_rounded;
            color = const Color(0xFF10B981);
            label = 'Synchronized';
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha((0.15 * 255).round()),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha((0.4 * 255).round())),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
