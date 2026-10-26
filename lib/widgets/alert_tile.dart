import 'package:flutter/material.dart';

import '../api/models.dart';
import 'common.dart';

class AlertTile extends StatelessWidget {
  final Alert alert;
  final VoidCallback onTap;

  const AlertTile({super.key, required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumb = alert.snapshotUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 84,
              child: thumb == null
                  ? ColoredBox(
                      color: Colors.black,
                      child: Icon(alert.hasHuman ? Icons.person : Icons.pets, color: Colors.white54),
                    )
                  : Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(formatTime(alert.createdAt), style: Theme.of(context).textTheme.bodySmall),
                  if (alert.clipStatus == 'ready')
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Row(children: [Icon(Icons.play_circle_outline, size: 16), SizedBox(width: 4), Text('Clip')]),
                    )
                  else if (alert.clipStatus == 'pending')
                    const Padding(padding: EdgeInsets.only(top: 4), child: Text('Clip uploading…')),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
