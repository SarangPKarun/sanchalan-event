import { SplashScreen } from "expo-router";
import { useAuth } from "./auth-context";

SplashScreen.preventAutoHideAsync();

// Keeps the native splash screen up while the launch-time auth check is
// still running, so there's no blank frame between "splash gone" and
// "auth state resolved" — matches Expo Router's current recommended pattern.
export function SplashScreenController() {
  const { state } = useAuth();

  if (state !== "loading") {
    SplashScreen.hide();
  }

  return null;
}
