import 'package:flutter/material.dart';

import '../../../../core/services/ws_service.dart';

class DispatchRelawanPage extends StatelessWidget {
  final String token;
  final WsService ws;
  const DispatchRelawanPage({super.key, required this.token, required this.ws});

  @override
  Widget build(BuildContext context) {
    // TODO Sprint B.4 — full dispatch implementation
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined, color: Colors.white24, size: 56),
          SizedBox(height: 16),
          Text(
            'Dispatch Relawan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Halaman ini akan menampilkan daftar relawan online\ndan SOS yang perlu di-dispatch.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
