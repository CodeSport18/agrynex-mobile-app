/// Server address shown on the sign-in screen. Set it when building, for example:
///   flutter build ios --dart-define=SERVER_URL=https://agrynex-cloud-server.onrender.com
const defaultServerUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'https://agrynex-cloud-server.onrender.com');
