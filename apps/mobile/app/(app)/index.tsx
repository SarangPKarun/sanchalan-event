import { StatusBar } from "expo-status-bar";
import { StyleSheet, Text, View, Pressable } from "react-native";
import { useAuth } from "../../lib/auth-context";

export default function AppHome() {
  const { signOut } = useAuth();

  return (
    <View style={styles.container}>
      <Text>You're in. This is the placeholder main app screen.</Text>
      <Pressable onPress={signOut} style={styles.button}>
        <Text style={styles.buttonText}>Log out</Text>
      </Pressable>
      <StatusBar style="auto" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#fff", alignItems: "center", justifyContent: "center", gap: 16 },
  button: { paddingVertical: 12, paddingHorizontal: 24, backgroundColor: "#111", borderRadius: 8 },
  buttonText: { color: "#fff", fontWeight: "600" },
});
