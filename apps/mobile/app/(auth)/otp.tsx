import { useEffect, useState } from "react";
import { View, Text, TextInput, Pressable, StyleSheet, ActivityIndicator } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { api } from "../../lib/api";
import { useAuth } from "../../lib/auth-context";
import type { Role } from "../../lib/types";

const RESEND_SECONDS = 30;

export default function OtpEntryScreen() {
  const { phoneNumber, role } = useLocalSearchParams<{ phoneNumber: string; role: Role }>();
  const { signIn } = useAuth();

  const [otp, setOtp] = useState("");
  const [resendSeconds, setResendSeconds] = useState(RESEND_SECONDS);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (resendSeconds <= 0) return;
    const id = setInterval(() => setResendSeconds((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(id);
  }, [resendSeconds]);

  async function handleVerify() {
    if (otp.length !== 6 || submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      const { data } = await api.post("/auth/otp/verify", { phoneNumber, otp, role });
      // No manual navigation needed — Stack.Protected at the root (auth
      // state), (app) (role), and (organizer) (profile/event status) levels
      // all react to signIn()'s state change and cascade to the right screen.
      await signIn({ accessToken: data.accessToken, refreshToken: data.refreshToken }, data.role);
    } catch {
      setError("That code is wrong or expired.");
    } finally {
      setSubmitting(false);
    }
  }

  async function handleResend() {
    if (resendSeconds > 0) return;
    setError(null);
    try {
      await api.post("/auth/otp/request", { phoneNumber, role });
    } catch {
      setError("Could not resend the code.");
    } finally {
      setResendSeconds(RESEND_SECONDS);
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Enter the code sent to {phoneNumber}</Text>

      <TextInput
        value={otp}
        onChangeText={(t) => setOtp(t.replace(/[^0-9]/g, "").slice(0, 6))}
        keyboardType="number-pad"
        maxLength={6}
        autoFocus
        style={styles.otpInput}
      />

      {error ? <Text style={styles.error}>{error}</Text> : null}

      <Pressable
        onPress={handleVerify}
        disabled={otp.length !== 6 || submitting}
        style={[styles.button, (otp.length !== 6 || submitting) && styles.buttonDisabled]}
      >
        {submitting ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Verify</Text>}
      </Pressable>

      <Pressable onPress={handleResend} disabled={resendSeconds > 0}>
        <Text style={resendSeconds > 0 ? styles.resendDisabled : styles.resendActive}>
          {resendSeconds > 0 ? `Resend code in ${resendSeconds}s` : "Resend code"}
        </Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#fff", justifyContent: "center", padding: 24, gap: 16 },
  title: { fontSize: 18, fontWeight: "600", textAlign: "center" },
  otpInput: {
    borderWidth: 1,
    borderColor: "#ccc",
    borderRadius: 8,
    padding: 12,
    fontSize: 28,
    letterSpacing: 12,
    textAlign: "center",
  },
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontWeight: "600" },
  resendDisabled: { color: "#999", textAlign: "center" },
  resendActive: { color: "#111", textAlign: "center", fontWeight: "600" },
});
