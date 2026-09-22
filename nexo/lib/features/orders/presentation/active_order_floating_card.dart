import 'package:flutter/material.dart';
import 'package:nexo/shared/models/create_order_response.dart';

class ActiveOrderFloatingCard extends StatefulWidget {
  final CreateOrderResponse order;
  final VoidCallback onTap;

  const ActiveOrderFloatingCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  State<ActiveOrderFloatingCard> createState() =>
      _ActiveOrderFloatingCardState();
}

class _ActiveOrderFloatingCardState extends State<ActiveOrderFloatingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _statusProgress(widget.order.status);
    final label = _statusLabel(widget.order.status);
    final segments = _segmentStates(progress);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF111111),
                  Color(0xFF171717),
                  Color(0xFF201A0F),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x44F2C21A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tu pedido sigue en camino',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pedido #${widget.order.orderId} · $label',
                            style: const TextStyle(
                              color: Color(0xFFD6D0C4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Color(0xFFF2C21A),
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressSegment(
                        state: segments[0],
                        animation: _shineController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProgressSegment(
                        state: segments[1],
                        animation: _shineController,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProgressSegment(
                        state: segments[2],
                        animation: _shineController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StageChip(label: 'Recibido', active: progress >= 0.25),
                    const SizedBox(width: 8),
                    _StageChip(label: 'Preparando', active: progress >= 0.55),
                    const SizedBox(width: 8),
                    _StageChip(label: 'Listo', active: progress >= 0.82),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  final String label;
  final bool active;

  const _StageChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0x1FF2C21A) : const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0x55F2C21A) : const Color(0x1FFFFFFF),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFFFFE39A) : const Color(0xFFC6C0B3),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  final double state;
  final Animation<double> animation;

  const _ProgressSegment({required this.state, required this.animation});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0x26FFFFFF)),
            if (state > 0)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: state),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: child,
                  );
                },
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1 + (animation.value * 2), 0),
                          end: Alignment(0 + (animation.value * 2), 0),
                          colors: const [
                            Color(0xFFF2C21A),
                            Color(0xFFFFE18A),
                            Color(0xFFF2C21A),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<double> _segmentStates(double progress) {
  if (progress <= 0.33) {
    return [progress / 0.33, 0, 0];
  }

  if (progress <= 0.66) {
    return [1, (progress - 0.33) / 0.33, 0];
  }

  return [1, 1, ((progress - 0.66) / 0.34).clamp(0, 1)];
}

double _statusProgress(String status) {
  return switch (status) {
    'preparing' => 0.66,
    'ready' => 0.9,
    'driver_assigned' => 0.92,
    'on_the_way' => 0.95,
    'delivered' => 1,
    'cancelled' => 1,
    _ => 0.33,
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'preparing' => 'Preparando tu pedido',
    'ready' => 'Listo para salir',
    'driver_assigned' => 'Repartidor asignado',
    'on_the_way' => 'Tu pedido va en camino',
    'delivered' => 'Entregado',
    'cancelled' => 'Cancelado',
    _ => 'Pedido recibido',
  };
}
