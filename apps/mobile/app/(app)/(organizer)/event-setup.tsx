import { useState } from "react";
import {
  View,
  Text,
  TextInput,
  Pressable,
  StyleSheet,
  ActivityIndicator,
  ScrollView,
  Platform,
} from "react-native";
import DateTimePicker, { DateTimePickerAndroid } from "@react-native-community/datetimepicker";
import { api } from "../../../lib/api";
import { router } from "expo-router";
import { useOrganizerData } from "../../../lib/organizer-context";
import type { EventType, BudgetTier } from "@sanchalan/shared-types";

const EVENT_TYPES: { value: EventType; label: string }[] = [
  { value: "wedding", label: "Wedding" },
  { value: "birthday", label: "Birthday" },
  { value: "corporate", label: "Corporate" },
  { value: "religious", label: "Religious" },
  { value: "custom", label: "Custom" },
];

const BUDGET_TIERS: { value: BudgetTier; label: string }[] = [
  { value: "essential", label: "Essential" },
  { value: "standard", label: "Standard" },
  { value: "premium", label: "Premium" },
  { value: "luxury", label: "Luxury" },
];

function toDateOnly(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export default function EventSetupScreen() {
  const data = useOrganizerData();
  const hasOtherEvents = data.status === "ready" && data.eventGroups.length > 0;

  const [eventType, setEventType] = useState<EventType>("wedding");
  const [name, setName] = useState("");
  const [region, setRegion] = useState("");
  const [primaryDate, setPrimaryDate] = useState<Date | null>(null);
  const [showIosPicker, setShowIosPicker] = useState(false);
  const [guestCountEstimate, setGuestCountEstimate] = useState("");
  const [totalBudget, setTotalBudget] = useState("");
  const [budgetTier, setBudgetTier] = useState<BudgetTier>("standard");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const guestCountNum = Number(guestCountEstimate);
  const totalBudgetNum = Number(totalBudget);

  const isValid =
    name.trim().length > 0 &&
    region.trim().length > 0 &&
    primaryDate !== null &&
    Number.isInteger(guestCountNum) &&
    guestCountNum > 0 &&
    totalBudgetNum > 0;

  function openDatePicker() {
    if (Platform.OS === "android") {
      DateTimePickerAndroid.open({
        value: primaryDate ?? new Date(),
        mode: "date",
        minimumDate: new Date(),
        onValueChange: (_event, selectedDate) => {
          setPrimaryDate(selectedDate);
        },
      });
    } else {
      setShowIosPicker(true);
    }
  }

  async function handleSubmit() {
    if (!isValid || submitting || !primaryDate) return;
    setSubmitting(true);
    setError(null);
    try {
      const { data: created } = await api.post<{ id: string }>("/event-groups", {
        eventType,
        name: name.trim(),
        region: region.trim(),
        totalBudget: totalBudgetNum,
        budgetTier,
        guestCountEstimate: guestCountNum,
        primaryDate: toDateOnly(primaryDate),
      },
      // The server builds the budget categories with the LLM, which can take longer than the client default.
      { timeout: 90_000 });
      await data.reloadEvents();
      // Replace (not push) so Back from the new event goes to "My events", not to this form.
      router.replace({
        pathname: "/(app)/(organizer)/event-home",
        params: { eventGroupId: created.id },
      });
    } catch {
      setError("Could not create your event. Please check the details and try again.");
      setSubmitting(false);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      {hasOtherEvents ? (
        <Pressable onPress={() => router.back()}>
          <Text style={styles.cancelText}>‹ Cancel</Text>
        </Pressable>
      ) : null}
      <Text style={styles.title}>Create event</Text>

      <Text style={styles.label}>Event type</Text>
      <View style={styles.chipRow}>
        {EVENT_TYPES.map((opt) => (
          <Pressable
            key={opt.value}
            onPress={() => setEventType(opt.value)}
            style={[styles.chip, eventType === opt.value && styles.chipActive]}
          >
            <Text style={eventType === opt.value ? styles.chipTextActive : styles.chipText}>
              {opt.label}
            </Text>
          </Pressable>
        ))}
      </View>

      <Text style={styles.label}>Event name</Text>
      <TextInput value={name} onChangeText={setName} placeholder="e.g. Priya & Rohan's Wedding" style={styles.input} />

      <Text style={styles.label}>Region</Text>
      <TextInput value={region} onChangeText={setRegion} placeholder="e.g. Mumbai" style={styles.input} />

      <Text style={styles.label}>Primary date</Text>
      <Pressable onPress={openDatePicker} style={styles.input}>
        <Text style={primaryDate ? styles.dateText : styles.datePlaceholder}>
          {primaryDate ? toDateOnly(primaryDate) : "Select a date"}
        </Text>
      </Pressable>
      {Platform.OS === "ios" && showIosPicker && (
        <DateTimePicker
          value={primaryDate ?? new Date()}
          mode="date"
          minimumDate={new Date()}
          display="inline"
          onValueChange={(_event, selectedDate) => {
            setShowIosPicker(false);
            setPrimaryDate(selectedDate);
          }}
          onDismiss={() => setShowIosPicker(false)}
        />
      )}

      <Text style={styles.label}>Guest count estimate</Text>
      <TextInput
        value={guestCountEstimate}
        onChangeText={setGuestCountEstimate}
        placeholder="e.g. 200"
        keyboardType="number-pad"
        style={styles.input}
      />

      <Text style={styles.label}>Total budget</Text>
      <TextInput
        value={totalBudget}
        onChangeText={setTotalBudget}
        placeholder="e.g. 500000"
        keyboardType="decimal-pad"
        style={styles.input}
      />

      <Text style={styles.label}>Budget tier</Text>
      <View style={styles.segmentRow}>
        {BUDGET_TIERS.map((opt) => (
          <Pressable
            key={opt.value}
            onPress={() => setBudgetTier(opt.value)}
            style={[styles.segment, budgetTier === opt.value && styles.segmentActive]}
          >
            <Text style={budgetTier === opt.value ? styles.chipTextActive : styles.chipText}>
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
        {submitting ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.buttonText}>Create event</Text>
        )}
      </Pressable>
      {submitting ? <Text style={styles.hint}>Building your budget…</Text> : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { backgroundColor: "#fff", padding: 24, gap: 12 },
  title: { fontSize: 20, fontWeight: "600", textAlign: "center", marginBottom: 8 },
  cancelText: { fontSize: 14, fontWeight: "600", color: "#111", marginTop: 32 },
  label: { fontSize: 14, fontWeight: "600", color: "#111" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12, fontSize: 16, justifyContent: "center" },
  dateText: { fontSize: 16, color: "#111" },
  datePlaceholder: { fontSize: 16, color: "#999" },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { paddingVertical: 8, paddingHorizontal: 14, borderRadius: 20, borderWidth: 1, borderColor: "#ccc" },
  chipActive: { backgroundColor: "#111", borderColor: "#111" },
  chipText: { color: "#111" },
  chipTextActive: { color: "#fff" },
  segmentRow: { flexDirection: "row", borderWidth: 1, borderColor: "#ccc", borderRadius: 8, overflow: "hidden" },
  segment: { flex: 1, paddingVertical: 10, alignItems: "center", borderLeftWidth: 1, borderLeftColor: "#ccc" },
  segmentActive: { backgroundColor: "#111" },
  error: { color: "#c00", textAlign: "center" },
  hint: { color: "#666", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center", marginTop: 8 },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontWeight: "600" },
});
