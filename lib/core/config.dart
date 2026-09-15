const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

const apiDemoDelay = int.fromEnvironment('API_DEMO_DELAY', defaultValue: 0);
const apiDemoFail = int.fromEnvironment('API_DEMO_FAIL', defaultValue: 0);
