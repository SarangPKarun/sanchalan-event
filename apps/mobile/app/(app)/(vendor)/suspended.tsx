import { View, Text, Pressable, StyleSheet } from "react-native";
import { useAuth } from "../../../lib/auth-context";

export default function SuspendedScreen() {
  const { signOut } = useAuth();
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Your listing is suspended</Text>
      <Text style={styles.body}>
        Your profile is hidden from families while our team looks into it. Please contact Sanchalan
        support to resolve this.
      </Text>
      <Pressable onPress={signOut} style={styles.button}>
        <Text style={styles.buttonText}>Log out</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#fff", padding: 24, justifyContent: "center", gap: 16 },
  title: { fontSize: 22, fontWeight: "600" },
  body: { fontSize: 15, color: "#333", lineHeight: 22 },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  buttonText: { color: "#fff", fontWeight: "600" },
});
