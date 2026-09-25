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
  const { refetch } = useOrganizerData();

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
        onChange: (_event, selectedDate) => {
          if (selectedDate) setPrimaryDate(selectedDate);
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
      await api.post("/event-groups", {
        eventType,
        name: name.trim(),
        region: region.trim(),
        totalBudget: totalBudgetNum,
        budgetTier,
        guestCountEstimate: guestCountNum,
        primaryDate: toDateOnly(primaryDate),
      });
      await refetch(); // Stack.Protected reacts to the status change automatically
    } catch {
      setError("Could not create your event. Please check the details and try again.");
      setSubmitting(false);
    }
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Set up your event</Text>

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
          onChange={(_event, selectedDate) => {
            setShowIosPicker(false);
            if (selectedDate) setPrimaryDate(selectedDate);
          }}
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
          <Text style={styles.buttonText}>Create my event</Text>
        )}
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { backgroundColor: "#fff", padding: 24, gap: 12 },
  title: { fontSize: 20, fontWeight: "600", textAlign: "center", marginBottom: 8 },
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
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center", marginTop: 8 },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontWeight: "600" },
});
