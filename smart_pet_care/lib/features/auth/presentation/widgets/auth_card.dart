// lib/features/auth/presentation/widgets/auth_card.dart
import 'package:flutter/material.dart';

class AuthCard extends StatelessWidget {
  final List<Widget> tabs;
  final List<Widget> tabViews;

  const AuthCard({super.key, required this.tabs, required this.tabViews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            spreadRadius: 5,
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Welcome Start',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TabBar(tabs: tabs),
          const SizedBox(height: 20),
          SizedBox(height: 620, child: TabBarView(children: tabViews)),
        ],
      ),
    );
  }
}
