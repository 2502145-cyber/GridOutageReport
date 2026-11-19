import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/compliance_rules.dart';
import 'data/repository.dart';
import 'data/seed_data.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/pdf_service.dart';
import 'services/report_service.dart';

void main() => runApp(const GridApp());

class GridApp extends StatefulWidget {
  const GridApp({super.key});

  @override
  State<GridApp> createState() => _GridAppState();
}

class _GridAppState extends State<GridApp> {
  late final ComplianceRules rules;
  late final Repository repo;

  @override
  void initState() {
    super.initState();
    rules = ComplianceRules();
    repo = Repository(rules);
    seedRepository(repo);
    repo.startEscalationTimer();
  }

  @override
  void dispose() {
    repo.dispose();
    rules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ComplianceRules>.value(value: rules),
        ChangeNotifierProvider<Repository>.value(value: repo),
        Provider<ReportService>.value(value: ReportService(repo)),
        Provider<PdfService>.value(value: PdfService(repo)),
      ],
      child: MaterialApp(
        title: 'Grid Report Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0D47A1),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: Consumer<Repository>(
          builder: (_, r, __) =>
              r.currentUser == null ? const LoginScreen() : const HomeShell(),
        ),
      ),
    );
  }
}
