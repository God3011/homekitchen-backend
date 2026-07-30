/// Shared Dart package for the Homely food marketplace.
///
/// Provides config, models, API client, auth, push, analytics, theme, and the
/// widgets shared between the Customer app and the Seller app.
library shared;

// Config
export 'config.dart';

// Models
export 'models/models.dart';

// API client
export 'api/api_client.dart';

// Auth
export 'auth/auth_service.dart';

// Push notifications
export 'services/push_service.dart';

// Analytics
export 'analytics/analytics.dart';

// Theme
export 'theme/app_colors.dart';
export 'theme/app_theme.dart';

// Widgets
export 'widgets/address_picker.dart';
export 'widgets/status_badge.dart';
export 'widgets/veg_badge.dart';
export 'widgets/homely_logo.dart';
