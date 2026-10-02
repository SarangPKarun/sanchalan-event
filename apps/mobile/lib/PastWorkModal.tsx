import { useEffect, useState } from "react";
import { View, Text, Pressable, StyleSheet, ActivityIndicator, Modal, TextInput } from "react-native";
import type { PastWorkBody, VendorPortfolioItem } from "@sanchalan/shared-types";

export function PastWorkModal({
  visible,
  item,
  onClose,
  onSave,
  onDelete,
}: {
  visible: boolean;
  /** null = adding a new entry */
  item: VendorPortfolioItem | null;
  onClose: () => void;
  onSave: (body: PastWorkBody) => Promise<string | null>;
  onDelete?: () => Promise<string | null>;
}) {
  const [title, setTitle] = useState("");
  const [caption, setCaption] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Re-seed the form each time the modal opens.
  useEffect(() => {
    if (!visible) return;
    setTitle(item?.title ?? "");
    setCaption(item?.caption ?? "");
    setError(null);
    setSaving(false);
  }, [visible, item]);

  async function run(action: () => Promise<string | null>) {
    setSaving(true);
    setError(null);
    const failure = await action();
    if (failure) {
      setError(failure);
      setSaving(false);
    }
  }

  function handleSave() {
    if (!title.trim()) {
      setError("Give this entry a title.");
      return;
    }
    run(() => onSave({ title: title.trim(), caption: caption.trim() || null }));
  }

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose}>
      <View style={styles.container}>
        <Text style={styles.title}>{item ? "Edit past work" : "Add past work"}</Text>
        <Text style={styles.hint}>
          Describe an event you worked on, e.g. &quot;Sharma wedding, Pune — full mandap décor&quot;.
        </Text>

        <Text style={styles.label}>Title</Text>
        <TextInput value={title} onChangeText={setTitle} style={styles.input} maxLength={150} placeholder="Sharma wedding, Pune" />

        <Text style={styles.label}>Details (optional)</Text>
        <TextInput
          value={caption}
          onChangeText={setCaption}
          style={[styles.input, styles.multiline]}
          multiline
          maxLength={500}
          placeholder="400 guests, 3-day event, floral mandap and stage"
        />

        {error && <Text style={styles.error}>{error}</Text>}

        <Pressable onPress={handleSave} disabled={saving} style={[styles.button, saving && styles.buttonDisabled]}>
          {saving ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Save</Text>}
        </Pressable>
        {item && onDelete && (
          <Pressable onPress={() => run(onDelete)} disabled={saving}>
            <Text style={styles.delete}>Delete entry</Text>
          </Pressable>
        )}
        <Pressable onPress={onClose} disabled={saving}>
          <Text style={styles.cancel}>Cancel</Text>
        </Pressable>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#fff", padding: 24, gap: 12, justifyContent: "center" },
  title: { fontSize: 22, fontWeight: "600" },
  hint: { color: "#666" },
  label: { fontSize: 14, color: "#666" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12 },
  multiline: { minHeight: 90, textAlignVertical: "top" },
  error: { color: "#c00" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: "#fff", fontWeight: "600" },
  delete: { color: "#c00", textAlign: "center", padding: 8 },
  cancel: { color: "#666", textAlign: "center", padding: 8 },
});
