import 'package:flutter/material.dart';
import '../../domain/entities/chat_message.dart';

/// Bandeau des messages épinglés — affiche le premier, collapsible si plusieurs.
class EpingleBanner extends StatefulWidget {
  final List<ChatMessage> epingles;
  const EpingleBanner({super.key, required this.epingles});

  @override
  State<EpingleBanner> createState() => _EpingleBannerState();
}

class _EpingleBannerState extends State<EpingleBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.epingles.isEmpty) return const SizedBox.shrink();

    final msgs = _expanded ? widget.epingles : [widget.epingles.first];
    final hasMore = widget.epingles.length > 1;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8E1),
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFE082), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête cliquable ──────────────────────────
          InkWell(
            onTap: hasMore ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 6),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded,
                      size: 13, color: Color(0xFFE65100)),
                  const SizedBox(width: 6),
                  const Text(
                    'Épinglé',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100),
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (hasMore) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.epingles.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (hasMore)
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFFE65100).withValues(alpha: 0.7),
                    ),
                ],
              ),
            ),
          ),

          // ── Messages épinglés ──────────────────────────
          ...msgs.map(
            (msg) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 34,
                    margin: const EdgeInsets.only(right: 8, top: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg.prenomAuteur,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFBF360C),
                          ),
                        ),
                        Text(
                          msg.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
