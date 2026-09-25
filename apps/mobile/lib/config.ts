const apiBaseUrl = process.env.EXPO_PUBLIC_API_URL;

if (!apiBaseUrl && __DEV__) {
  console.warn(
    "[config] EXPO_PUBLIC_API_URL not set — defaulting to http://localhost:3000. " +
      "Android emulator needs http://10.0.2.2:3000; a physical device needs your machine's LAN IP."
  );
}

export const API_BASE_URL = apiBaseUrl ?? "http://localhost:3000";
