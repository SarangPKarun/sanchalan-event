import { useState } from "react";
import { View, Text, TextInput, Pressable, StyleSheet, ActivityIndicator } from "react-native";
import { router } from "expo-router";
import { parsePhoneNumberFromString } from "libphonenumber-js/max";
import { api } from "../../lib/api";
import type { Role } from "../../lib/types";
import { DEFAULT_COUNTRY, type Country } from "../../lib/countryCodes";
import { CountryCodePicker } from "../../lib/CountryCodePicker";

export default function PhoneEntryScreen() {
  const [country, setCountry] = useState<Country>(DEFAULT_COUNTRY);
  const [localNumber, setLocalNumber] = useState("");
  const [role, setRole] = useState<Role>("organizer");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const digitsOnly = localNumber.replace(/\D/g, "");
  const normalized = `${country.dialCode}${digitsOnly}`;
  // Same per-country mobile check as the backend (e.g. +91 needs exactly 10 digits).
  const parsed = parsePhoneNumberFromString(normalized);
  const phoneType = parsed?.isValid() ? parsed.getType() : undefined;
  const isValid = phoneType === "MOBILE" || phoneType === "FIXED_LINE_OR_MOBILE";
  const showInvalidHint = digitsOnly.length > 0 && !isValid;

  async function handleSubmit() {
    if (!isValid || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await api.post("/auth/otp/request", { phoneNumber: normalized, role });
      router.push({ pathname: "/(auth)/otp", params: { phoneNumber: normalized, role } });
    } catch (err) {
      const status = (err as { response?: { status?: number } }).response?.status;
      setError(
        status === 400
          ? `Enter a valid ${country.name} phone number.`
          : "Could not send a code. Check the number and try again."
      );
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

      <View style={styles.phoneRow}>
        <CountryCodePicker value={country} onChange={setCountry} />
        <TextInput
          value={localNumber}
          onChangeText={setLocalNumber}
          placeholder="98765 43210"
          keyboardType="phone-pad"
          autoFocus
          style={styles.phoneInput}
        />
      </View>

      {showInvalidHint && !error ? (
        <Text style={styles.error}>Enter a valid {country.name} phone number.</Text>
      ) : null}
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
  phoneRow: { flexDirection: "row", gap: 8 },
  phoneInput: { flex: 1, borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12, fontSize: 16 },
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontWeight: "600" },
});
