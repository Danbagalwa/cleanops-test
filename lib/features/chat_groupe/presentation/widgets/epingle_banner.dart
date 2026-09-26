import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_bubble.dart';

/// Bandeau des messages épinglés (haut de la conversation) : affiche le plus
/// récent, se déplie s'il y en a plusieurs.
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
      decoration: BoxDecoration(
        color: couleurEpingle.withValues(alpha: 0.07),
        border: const Border(bottom: BorderSide(color: AppColors.grisMedium)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap:
                hasMore ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 4),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded,
                      size: 14, color: couleurEpingle),
                  const SizedBox(width: 6),
                  Text(
                    hasMore
                        ? '${widget.epingles.length} messages épinglés'
                        : 'Message épinglé',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: couleurEpingle,
                    ),
                  ),
                  const Spacer(),
                  if (hasMore)
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: couleurEpingle,
                    ),
                ],
              ),
            ),
          ),
          for (final msg in msgs)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 34,
                    margin: const EdgeInsets.only(right: 8, top: 1),
                    decoration: BoxDecoration(
                      color: couleurEpingle,
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
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: couleurAuteur(msg.prenomAuteur),
                          ),
                        ),
                        Text(
                          msg.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.grisDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
