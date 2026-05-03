import 'package:flutter/material.dart';
import 'package:nexo/features/cart/application/cart_scope.dart';
import 'package:nexo/features/cart/presentation/cart_page.dart';

class CartIcon extends StatelessWidget {
  const CartIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final cartController = CartScope.of(context);

    return IconButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CartPage(),
          ),
        );
      },
      icon: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 24),
            if (cartController.totalItems > 0)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    cartController.totalItems.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
