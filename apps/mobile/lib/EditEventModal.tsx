import { useEffect, useState } from "react";
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  ActivityIndicator,
  ScrollView,
  Modal,
  TextInput,
  Platform,
} from "react-native";
import DateTimePicker, { DateTimePickerAndroid } from "@react-native-community/datetimepicker";
import { api } from "./api";
import type {
  BudgetTier,
  EventGroup,
  UpdateEventGroupBody,
  UpdateEventGroupResponse,
} from "@sanchalan/shared-types";

const BUDGET_TIERS: { value: BudgetTier; label: string }[] = [
  { value: "essential", label: "Essential" },
  { value: "standard", label: "Standard" },
  { value: "premium", label: "Premium" },
  { value: "luxury", label: "Luxury" },
];

function toDateOnly(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function EditEventModal({
  visible,
  eventGroup,
  onClose,
  onSaved,
}: {
  visible: boolean;
  eventGroup: EventGroup;
  onClose: () => void;
  onSaved: (result: UpdateEventGroupResponse) => void;
}) {
  const [name, setName] = useState("");
  const [totalBudget, setTotalBudget] = useState("");
  const [tier, setTier] = useState<BudgetTier>("standard");
  const [guests, setGuests] = useState("");
  const [date, setDate] = useState<Date>(new Date());
  const [adjustment, setAdjustment] = useState<"rescale" | "keep">("rescale");
  const [showIosPicker, setShowIosPicker] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Re-seed the form from the event each time the modal opens.
  useEffect(() => {
    if (!visible) return;
    setName(eventGroup.name);
    setTotalBudget(String(eventGroup.totalBudget));
    setTier(eventGroup.budgetTier);
    setGuests(String(eventGroup.guestCountEstimate));
    setDate(new Date(eventGroup.primaryDate));
    setAdjustment("rescale");
    setShowIosPicker(false);
    setError(null);
  }, [visible, eventGroup]);

  const newTotal = Number(totalBudget);
  const totalChanged = Number.isFinite(newTotal) && newTotal !== Number(eventGroup.totalBudget);

  function openDatePicker() {
    if (Platform.OS === "android") {
      DateTimePickerAndroid.open({
        value: date,
        mode: "date",
        onValueChange: (_event, selected) => {
          setDate(selected);
        },
      });
    } else {
      setShowIosPicker(true);
    }
  }

  async function handleSave() {
    if (saving) return;
    const trimmedName = name.trim();
    const guestCount = Number(guests);
    if (!trimmedName) return setError("Enter an event name.");
    if (!Number.isFinite(newTotal) || newTotal <= 0) return setError("Enter a valid total budget.");
    if (!Number.isInteger(guestCount) || guestCount <= 0) return setError("Enter a valid guest count.");

    const body: UpdateEventGroupBody = {};
    if (trimmedName !== eventGroup.name) body.name = trimmedName;
    if (totalChanged) {
      body.totalBudget = newTotal;
      body.budgetAdjustment = adjustment;
    }
    if (tier !== eventGroup.budgetTier) body.budgetTier = tier;
    if (guestCount !== eventGroup.guestCountEstimate) body.guestCountEstimate = guestCount;
    if (toDateOnly(date) !== eventGroup.primaryDate) body.primaryDate = toDateOnly(date);

    if (Object.keys(body).length === 0) {
      onClose();
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const { data } = await api.patch<UpdateEventGroupResponse>(
        `/event-groups/${eventGroup.id}`,
        body
      );
      onSaved(data);
    } catch (err: any) {
      setError(err?.response?.data?.error ?? "Could not save. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  const dateChanged = toDateOnly(date) !== eventGroup.primaryDate;

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <ScrollView contentContainerStyle={styles.modal}>
        <Text style={styles.modalTitle}>Edit event</Text>

        <Text style={styles.label}>Event name</Text>
        <TextInput value={name} onChangeText={setName} style={styles.input} />

        <Text style={styles.label}>Total budget</Text>
        <TextInput
          value={totalBudget}
          onChangeText={setTotalBudget}
          keyboardType="decimal-pad"
          style={styles.input}
        />
        {totalChanged ? (
          <View style={styles.choiceBox}>
            <Text style={styles.choiceTitle}>What about the category amounts?</Text>
            {(
              [
                ["rescale", "Rescale all categories proportionally"],
                ["keep", "Keep amounts as they are (I'll adjust them myself)"],
              ] as const
            ).map(([value, label]) => (
              <Pressable
                key={value}
                onPress={() => setAdjustment(value)}
                style={[styles.chip, adjustment === value && styles.chipActive]}
              >
                <Text style={adjustment === value ? styles.chipTextActive : styles.chipText}>
                  {label}
                </Text>
              </Pressable>
            ))}
          </View>
        ) : null}

        <Text style={styles.label}>Budget tier</Text>
        <View style={styles.chipRow}>
          {BUDGET_TIERS.map((opt) => (
            <Pressable
              key={opt.value}
              onPress={() => setTier(opt.value)}
              style={[styles.chip, tier === opt.value && styles.chipActive]}
            >
              <Text style={tier === opt.value ? styles.chipTextActive : styles.chipText}>
                {opt.label}
              </Text>
            </Pressable>
          ))}
        </View>

        <Text style={styles.label}>Guest count estimate</Text>
        <TextInput
          value={guests}
          onChangeText={setGuests}
          keyboardType="number-pad"
          style={styles.input}
        />

        <Text style={styles.label}>Event date</Text>
        <Pressable onPress={openDatePicker} style={styles.input}>
          <Text style={styles.dateText}>{toDateOnly(date)}</Text>
        </Pressable>
        {Platform.OS === "ios" && showIosPicker && (
          <DateTimePicker
            value={date}
            mode="date"
            display="inline"
            onValueChange={(_event, selected) => {
              setShowIosPicker(false);
              setDate(selected);
            }}
            onDismiss={() => setShowIosPicker(false)}
          />
        )}
        {dateChanged ? (
          <Text style={styles.hint}>
            Task due dates won't move automatically. Re-run the roadmap if you want them recalculated.
          </Text>
        ) : null}

        {error ? <Text style={styles.error}>{error}</Text> : null}
        <Pressable
          onPress={handleSave}
          disabled={saving}
          style={[styles.button, saving && styles.buttonDisabled]}
        >
          {saving ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Save</Text>}
        </Pressable>
        <Pressable onPress={onClose} style={styles.closeButton}>
          <Text style={styles.closeButtonText}>Cancel</Text>
        </Pressable>
      </ScrollView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modal: { flexGrow: 1, backgroundColor: "#fff", padding: 24, paddingTop: 64, gap: 12 },
  modalTitle: { fontSize: 18, fontWeight: "600", textAlign: "center" },
  label: { fontSize: 14, fontWeight: "600", color: "#444" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12, fontSize: 16 },
  dateText: { fontSize: 16, color: "#111" },
  hint: { fontSize: 13, color: "#666" },
  choiceBox: { gap: 8, padding: 12, borderRadius: 8, backgroundColor: "#f5f5f5" },
  choiceTitle: { fontSize: 14, fontWeight: "600" },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { paddingVertical: 8, paddingHorizontal: 14, borderRadius: 20, borderWidth: 1, borderColor: "#ccc" },
  chipActive: { backgroundColor: "#111", borderColor: "#111" },
  chipText: { color: "#111" },
  chipTextActive: { color: "#fff" },
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center", marginTop: 8 },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontWeight: "600" },
  closeButton: { alignItems: "center", padding: 14 },
  closeButtonText: { color: "#111", fontWeight: "600" },
});
