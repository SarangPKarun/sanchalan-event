import { Stack } from "expo-router";
import { AuthProvider, useAuth } from "../lib/auth-context";
import { SplashScreenController } from "../lib/splash";

function RootNavigator() {
  const { state } = useAuth();

  return (
    <Stack>
      <Stack.Protected guard={state === "authed"}>
        <Stack.Screen name="(app)" />
      </Stack.Protected>

      <Stack.Protected guard={state === "unauthed"}>
        <Stack.Screen name="(auth)" />
      </Stack.Protected>
    </Stack>
  );
}

export default function RootLayout() {
  return (
    <AuthProvider>
      <SplashScreenController />
      <RootNavigator />
    </AuthProvider>
  );
}
