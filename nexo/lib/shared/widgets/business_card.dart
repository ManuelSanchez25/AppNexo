import 'package:flutter/material.dart';
import 'package:nexo/features/restaurant/presentation/business_detail_page.dart';

class BusinessCard extends StatelessWidget {
  final int businessId;
  final String name;
  final String description;
  final String time;
  final double rating;
  final String imageUrl;
  final bool isOpen;
  final String availabilityLabel;

  const BusinessCard({
    super.key,
    required this.businessId,
    required this.name,
    required this.description,
    required this.time,
    required this.rating,
    required this.imageUrl,
    required this.isOpen,
    required this.availabilityLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BusinessDetailPage(
                businessId: businessId,
                name: name,
                description: description,
                time: time,
                rating: rating,
                isOpen: isOpen,
                availabilityLabel: availabilityLabel,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFEAE5DA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 102,
                height: 102,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EE),
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.hardEdge,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _BusinessPlaceholder(),
                      )
                    : const _BusinessPlaceholder(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF151515),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B645A),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaPill(
                            icon: isOpen
                                ? Icons.bolt_rounded
                                : Icons.pause_circle_rounded,
                            label: availabilityLabel,
                            iconColor: isOpen
                                ? const Color(0xFF1E8E4D)
                                : const Color(0xFFE24A2B),
                          ),
                          _MetaPill(
                            icon: Icons.timer_rounded,
                            label: '$time min',
                          ),
                          _MetaPill(
                            icon: Icons.star_rounded,
                            label: rating.toStringAsFixed(1),
                            iconColor: const Color(0xFFF2C21A),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFF2C21A),
                    ),
                  ),
                  if (!isOpen) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDE8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Cerrado',
                        style: TextStyle(
                          color: Color(0xFFE24A2B),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessPlaceholder extends StatelessWidget {
  const _BusinessPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.storefront_outlined, color: Color(0xFF6B645A));
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _MetaPill({
    required this.icon,
    required this.label,
    this.iconColor = const Color(0xFF534C43),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2A26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
