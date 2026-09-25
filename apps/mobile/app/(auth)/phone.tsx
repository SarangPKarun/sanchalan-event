import { useState } from "react";
import { View, Text, TextInput, Pressable, StyleSheet, ActivityIndicator } from "react-native";
import { router } from "expo-router";
import { api } from "../../lib/api";
import type { Role } from "../../lib/types";

// E.164, matching the backend's exact validation (mandatory leading "+", no spaces).
const PHONE_REGEX = /^\+[1-9]\d{7,14}$/;

export default function PhoneEntryScreen() {
  const [phoneNumber, setPhoneNumber] = useState("");
  const [role, setRole] = useState<Role>("organizer");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const normalized = phoneNumber.replace(/\s+/g, "");
  const isValid = PHONE_REGEX.test(normalized);

  async function handleSubmit() {
    if (!isValid || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await api.post("/auth/otp/request", { phoneNumber: normalized, role });
      router.push({ pathname: "/(auth)/otp", params: { phoneNumber: normalized, role } });
    } catch {
      setError("Could not send a code. Check the number and try again.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Enter your phone number</Text>

      <View style={styles.roleRow}>
        <Pressable
          onPress={() => setRole("organizer")}
          style={[styles.roleChip, role === "organizer" && styles.roleChipActive]}
        >
          <Text style={role === "organizer" ? styles.roleTextActive : styles.roleText}>
            I'm an Organizer
          </Text>
        </Pressable>
        <Pressable
          onPress={() => setRole("vendor")}
          style={[styles.roleChip, role === "vendor" && styles.roleChipActive]}
        >
          <Text style={role === "vendor" ? styles.roleTextActive : styles.roleText}>I'm a Vendor</Text>
        </Pressable>
      </View>

      <TextInput
        value={phoneNumber}
        onChangeText={setPhoneNumber}
        placeholder="+919876543210"
        keyboardType="phone-pad"
        autoFocus
        style={styles.input}
      />

      {error ? <Text style={styles.error}>{error}</Text> : null}

      <Pressable
        onPress={handleSubmit}
        disabled={!isValid || submitting}
        style={[styles.button, (!isValid || submitting) && styles.buttonDisabled]}
      >
        {submitting ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Send code</Text>}
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#fff", justifyContent: "center", padding: 24, gap: 16 },
  title: { fontSize: 20, fontWeight: "600", textAlign: "center" },
  roleRow: { flexDirection: "row", gap: 8, justifyContent: "center" },
  roleChip: { paddingVertical: 8, paddingHorizontal: 14, borderRadius: 20, borderWidth: 1, borderColor: "#ccc" },
  roleChipActive: { backgroundColor: "#111", borderColor: "#111" },
  roleText: { color: "#111" },
  roleTextActive: { color: "#fff" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12, fontSize: 16 },
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontWeight: "600" },
});
