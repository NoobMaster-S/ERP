import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import '../features/authentication/presentation/bloc/auth_bloc.dart';
import '../core/sync/sync_engine.dart';
import 'router/app_router.dart';

class BusinessERPApp extends StatefulWidget {
  final AuthBloc authBloc;
  final SyncEngine syncEngine;

  const BusinessERPApp({
    super.key,
    required this.authBloc,
    required this.syncEngine,
  });

  @override
  State<BusinessERPApp> createState() => _BusinessERPAppState();
}

class _BusinessERPAppState extends State<BusinessERPApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter(
      authBloc: widget.authBloc,
      syncEngine: widget.syncEngine,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.authBloc,
      child: MaterialApp.router(
        title: 'ERP Business Platform',
        theme: AppTheme.darkTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
