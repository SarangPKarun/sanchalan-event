import { View, Text, Pressable, ActivityIndicator, StyleSheet } from "react-native";
import { Stack } from "expo-router";
import { OrganizerDataProvider, useOrganizerData } from "../../../lib/organizer-context";

function OrganizerNavigator() {
  const data = useOrganizerData();

  // No <Stack> is mounted at all during loading/error — unlike the root
  // layout (masked by the native splash screen), nothing masks a blank
  // <Stack> with zero true Stack.Protected guards at this nesting level.
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

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Protected guard={data.status === "needs-profile"}>
        <Stack.Screen name="profile-setup" />
      </Stack.Protected>

      <Stack.Protected guard={data.status === "needs-event"}>
        <Stack.Screen name="event-setup" />
      </Stack.Protected>

      <Stack.Protected guard={data.status === "ready"}>
        <Stack.Screen name="event-home" />
        <Stack.Screen name="vendors" />
        <Stack.Screen name="vendor-detail" />
      </Stack.Protected>
    </Stack>
  );
}

export default function OrganizerLayout() {
  return (
    <OrganizerDataProvider>
      <OrganizerNavigator />
    </OrganizerDataProvider>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, backgroundColor: "#fff", alignItems: "center", justifyContent: "center", gap: 16, padding: 24 },
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, paddingVertical: 12, paddingHorizontal: 24 },
  buttonText: { color: "#fff", fontWeight: "600" },
});
