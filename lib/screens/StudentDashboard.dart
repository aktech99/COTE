import 'package:flutter/material.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DashboardButton(
              label: "Shorts",
              icon: Icons.video_library,
              onTap: () => Navigator.pushNamed(context, '/student_home'),
            ),
            const SizedBox(height: 20),
            DashboardButton(
              label: "Notes",
              icon: Icons.notes,
              onTap: () => Navigator.pushNamed(context, '/StudentNotesPage'),
            ),
            const SizedBox(height: 20),
            DashboardButton(
              label: "Quiz Battle",
              icon: Icons.sports_esports,
              onTap: () => Navigator.pushNamed(context, '/StudentQuizPage'),
            ),
            const SizedBox(height: 20),
            DashboardButton(
              label: "Bookmarks",
              icon: Icons.bookmark,
              onTap: () => Navigator.pushNamed(context, '/bookmarks'),
            ),
            const SizedBox(height: 20),
            DashboardButton(
              label: "Profile",
              icon: Icons.person,
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardButton({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 28),
      label: Text(label, style: const TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }
}
