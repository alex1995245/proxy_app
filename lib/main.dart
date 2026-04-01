import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/connection_provider.dart';
import 'providers/proxy_list_provider.dart';
import 'providers/settings_provider.dart';
import 'services/proxifly_api_service.dart';
import 'services/proxy_connection_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init storage
  await StorageService.instance.init();

  final storage = StorageService.instance;
  final apiService = ProxiflyApiService(apiKey: storage.apiKey);
  final connectionService = ProxyConnectionService.instance;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storage),
        ),
        ChangeNotifierProvider(
          create: (_) => ProxyListProvider(
            apiService: apiService,
            storage: storage,
          ),
        ),
        ChangeNotifierProxyProvider2<ProxyListProvider, SettingsProvider,
            ConnectionProvider>(
          create: (ctx) => ConnectionProvider(
            proxyListProvider: ctx.read<ProxyListProvider>(),
            settings: ctx.read<SettingsProvider>(),
            storage: storage,
            connectionService: connectionService,
            apiService: apiService,
          ),
          update: (ctx, proxyList, settings, prev) =>
              prev ??
              ConnectionProvider(
                proxyListProvider: proxyList,
                settings: settings,
                storage: storage,
                connectionService: connectionService,
                apiService: apiService,
              ),
        ),
      ],
      child: const ProxyApp(),
    ),
  );
}
