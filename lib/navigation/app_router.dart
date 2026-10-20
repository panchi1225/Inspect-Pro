import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/admin_screen.dart';
import '../screens/home_screen.dart';
import '../screens/inspection_input_screen.dart';
import '../screens/inspector_selection_screen.dart';
import '../screens/login_screen.dart';
import '../screens/machine_selection_screen_v2.dart';
import '../screens/master_data_management_screen.dart';
import '../screens/record_detail_screen.dart';
import '../screens/site_selection_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'app_navigation.dart';

GoRouter createAppRouter({FirestoreService? dataSource}) {
  final auth = AuthService();
  return GoRouter(
    initialLocation: AppPaths.login,
    refreshListenable: auth,
    extraCodec: SessionRouteDataCodec(),
    redirect: (context, state) {
      final path = state.uri.path;
      if (!auth.isAuthenticated) {
        return path == AppPaths.login ? null : AppPaths.login;
      }
      if (path == AppPaths.login || path == '/') return AppPaths.home;
      final data = state.extra is AppRouteData
          ? state.extra as AppRouteData
          : null;
      if (path.startsWith(AppPaths.inspectors) && data?.siteName == null) {
        return AppPaths.sites;
      }
      if (path.startsWith(AppPaths.machines) && data?.inspectorName == null) {
        return AppPaths.inspectors;
      }
      if (path == AppPaths.input && data?.machine == null) {
        return AppPaths.machines;
      }
      if (path == AppPaths.detail && data?.record == null) {
        return AppPaths.records;
      }
      if (path == AppPaths.masters && !auth.isAdmin) return AppPaths.home;
      return null;
    },
    routes: [
      _screenRoute(
        path: AppPaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      _screenRoute(
        path: AppPaths.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          _screenRoute(
            path: 'sites',
            builder: (context, state) =>
                SiteSelectionScreen(dataSource: dataSource),
            routes: [
              _screenRoute(
                path: 'inspectors',
                builder: (context, state) => InspectorSelectionScreen(
                  siteName: (state.extra as AppRouteData).siteName!,
                  dataSource: dataSource,
                ),
                routes: [
                  _screenRoute(
                    path: 'machines',
                    builder: (context, state) {
                      final data = state.extra as AppRouteData;
                      return MachineSelectionScreenV2(
                        siteName: data.siteName!,
                        inspectorName: data.inspectorName!,
                        dataSource: dataSource,
                      );
                    },
                    routes: [
                      _screenRoute(
                        path: 'input',
                        builder: (context, state) {
                          final data = state.extra as AppRouteData;
                          return InspectionInputScreen(
                            siteName: data.siteName!,
                            inspectorName: data.inspectorName!,
                            machine: data.machine!,
                            dataSource: dataSource,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          _screenRoute(
            path: 'records',
            builder: (context, state) => AdminScreen(dataSource: dataSource),
            routes: [
              _screenRoute(
                path: 'detail',
                builder: (context, state) {
                  final data = state.extra as AppRouteData;
                  return RecordDetailScreen(
                    record: data.record!,
                    dataSource: dataSource,
                    onDeleted: data.onRecordDeleted,
                  );
                },
              ),
            ],
          ),
          _screenRoute(
            path: 'masters',
            builder: (context, state) =>
                MasterDataManagementScreen(dataSource: dataSource),
          ),
        ],
      ),
    ],
  );
}

// The browser supplies its own swipe animation. Web pages change in the same
// frame without layering a second Cupertino/Material transition over that swipe.
GoRoute _screenRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  routes: routes,
  pageBuilder: (context, state) {
    final child = builder(context, state);
    return kIsWeb
        ? NoTransitionPage<void>(key: state.pageKey, child: child)
        : MaterialPage<void>(key: state.pageKey, child: child);
  },
);
