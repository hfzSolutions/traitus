import 'package:flutter/material.dart';
import 'package:traitus/ui/chat_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const ChatListPage(isInTabView: true),
    );
  }
}

