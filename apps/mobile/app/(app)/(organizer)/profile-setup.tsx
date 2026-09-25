import { useState } from "react";
import { View, Text, TextInput, Pressable, StyleSheet, ActivityIndicator } from "react-native";
import { api } from "../../../lib/api";
import { useOrganizerData } from "../../../lib/organizer-context";
import type { OrganizerType } from "@sanchalan/shared-types";

const ORGANIZER_TYPES: { value: OrganizerType; label: string }[] = [
  { value: "individual", label: "Individual" },
  { value: "family", label: "Family" },
  { value: "company", label: "Company" },
  { value: "committee", label: "Committee" },
];

export default function ProfileSetupScreen() {
  const { refetch } = useOrganizerData();

  const [displayName, setDisplayName] = useState("");
  const [organizerType, setOrganizerType] = useState<OrganizerType | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isValid = displayName.trim().length > 0 && organizerType !== null;

  async function handleSubmit() {
    if (!isValid || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await api.post("/organizers/me/profile", {
        displayName: displayName.trim(),
        organizerType,
      });
      await refetch(); // Stack.Protected reacts to the status change automatically
    } catch {
      setError("Could not save your profile. Please try again.");
      setSubmitting(false);
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Tell us about yourself</Text>

      <TextInput
        value={displayName}
        onChangeText={setDisplayName}
        placeholder="Your name"
        autoFocus
        style={styles.input}
      />

      <View style={styles.chipRow}>
        {ORGANIZER_TYPES.map((opt) => (
          <Pressable
            key={opt.value}
            onPress={() => setOrganizerType(opt.value)}
            style={[styles.chip, organizerType === opt.value && styles.chipActive]}
          >
            <Text style={organizerType === opt.value ? styles.chipTextActive : styles.chipText}>
              {opt.label}
            </Text>
          </Pressable>
        ))}
      </View>

      {error ? <Text style={styles.error}>{error}</Text> : null}

      <Pressable
        onPress={handleSubmit}
        disabled={!isValid || submitting}
        style={[styles.button, (!isValid || submitting) && styles.buttonDisabled]}
      >
        {submitting ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Continue</Text>}
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#fff", justifyContent: "center", padding: 24, gap: 16 },
  title: { fontSize: 20, fontWeight: "600", textAlign: "center" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12, fontSize: 16 },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8, justifyContent: "center" },
  chip: { paddingVertical: 8, paddingHorizontal: 14, borderRadius: 20, borderWidth: 1, borderColor: "#ccc" },
  chipActive: { backgroundColor: "#111", borderColor: "#111" },
  chipText: { color: "#111" },
  chipTextActive: { color: "#fff" },
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontWeight: "600" },
});
