import { Slot, Redirect } from "expo-router";
import { ActivityIndicator, View } from "react-native";
import { AuthProvider, useAuth } from "../lib/auth-context";

function Gate() {
  const { state } = useAuth();

  if (state === "loading") {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
        <ActivityIndicator />
      </View>
    );
  }

  if (state === "unauthed") {
    return <Redirect href="/(auth)/phone" />;
  }

  return <Slot />;
}

export default function RootLayout() {
  return (
    <AuthProvider>
      <Gate />
    </AuthProvider>
  );
}
