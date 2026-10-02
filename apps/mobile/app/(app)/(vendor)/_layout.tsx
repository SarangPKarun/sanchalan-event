import { View, Text, Pressable, ActivityIndicator, StyleSheet } from "react-native";
import { Stack } from "expo-router";
import { VendorDataProvider, useVendorData } from "../../../lib/vendor-context";

function VendorNavigator() {
  const data = useVendorData();

  if (data.status === "loading") {
    return (
      <View style={styles.center}>
        <ActivityIndicator />
      </View>
    );
  }

  if (data.status === "error") {
    return (
      <View style={styles.center}>
        <Text style={styles.error}>Something went wrong loading your account.</Text>
        <Pressable onPress={data.refetch} style={styles.button}>
          <Text style={styles.buttonText}>Retry</Text>
        </Pressable>
      </View>
    );
  }

  const status = data.vendor.status;

  // Declaration order matters: the first screen whose guard passes is the initial route,
  // so a published vendor lands on "home" and reaches "profile" via the Edit button.
  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Protected guard={status === "published"}>
        <Stack.Screen name="home" />
      </Stack.Protected>
      <Stack.Protected guard={status === "pending_review"}>
        <Stack.Screen name="under-review" />
      </Stack.Protected>
      <Stack.Protected guard={status === "suspended"}>
        <Stack.Screen name="suspended" />
      </Stack.Protected>
      <Stack.Protected guard={status === "draft" || status === "rejected" || status === "published"}>
        <Stack.Screen name="profile" />
      </Stack.Protected>
    </Stack>
  );
}

export default function VendorLayout() {
  return (
    <VendorDataProvider>
      <VendorNavigator />
    </VendorDataProvider>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, backgroundColor: "#fff", alignItems: "center", justifyContent: "center", gap: 16, padding: 24 },
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, paddingVertical: 12, paddingHorizontal: 24 },
  buttonText: { color: "#fff", fontWeight: "600" },
});
