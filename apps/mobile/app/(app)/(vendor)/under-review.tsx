import { useState } from "react";
import { View, Text, Pressable, StyleSheet, ActivityIndicator } from "react-native";
import { api } from "../../../lib/api";
import { useAuth } from "../../../lib/auth-context";
import { apiErrorMessage, useVendorData } from "../../../lib/vendor-context";
import type { VendorMeResponse } from "@sanchalan/shared-types";

export default function UnderReviewScreen() {
  const data = useVendorData();
  const { signOut } = useAuth();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (data.status !== "ready") return null;
  const { vendor } = data;

  async function withdraw() {
    setBusy(true);
    setError(null);
    try {
      const { data: updated } = await api.post<VendorMeResponse>("/vendor/me/withdraw");
      data.apply(updated);
    } catch (err) {
      setError(apiErrorMessage(err, "Could not withdraw your profile."));
      setBusy(false);
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Your profile is under review</Text>
      <Text style={styles.body}>
        {vendor.businessName ?? "Your business"} was submitted
        {vendor.submittedAt ? ` on ${new Date(vendor.submittedAt).toLocaleDateString()}` : ""}.
        We&apos;ll review it and it will appear to families once approved.
      </Text>
      <Text style={styles.muted}>Need to change something? Withdraw it, edit, and resubmit.</Text>
      {error && <Text style={styles.error}>{error}</Text>}
      <Pressable onPress={withdraw} disabled={busy} style={[styles.button, busy && styles.buttonDisabled]}>
        {busy ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Withdraw to edit</Text>}
      </Pressable>
      <Pressable onPress={signOut}>
        <Text style={styles.link}>Log out</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#fff", padding: 24, justifyContent: "center", gap: 16 },
  title: { fontSize: 22, fontWeight: "600" },
  body: { fontSize: 15, color: "#333", lineHeight: 22 },
  muted: { color: "#666" },
  error: { color: "#c00" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: "#fff", fontWeight: "600" },
  link: { color: "#666", textAlign: "center", padding: 8 },
});
