import { useState } from "react";
import { View, Text, TextInput, Pressable, Modal, FlatList, StyleSheet } from "react-native";
import { COUNTRIES, flagEmoji, type Country } from "./countryCodes";

export function CountryCodePicker({
  value,
  onChange,
}: {
  value: Country;
  onChange: (country: Country) => void;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");

  const filtered = COUNTRIES.filter((c) => {
    const q = query.trim().toLowerCase();
    if (!q) return true;
    return c.name.toLowerCase().includes(q) || c.dialCode.includes(q);
  });

  return (
    <>
      <Pressable onPress={() => setOpen(true)} style={styles.trigger}>
        <Text style={styles.triggerText}>
          {flagEmoji(value.iso2)} {value.dialCode}
        </Text>
      </Pressable>

      <Modal visible={open} animationType="slide" onRequestClose={() => setOpen(false)}>
        <View style={styles.modal}>
          <Text style={styles.modalTitle}>Select a country</Text>
          <TextInput
            value={query}
            onChangeText={setQuery}
            placeholder="Search country or code"
            autoFocus
            style={styles.search}
          />
          <FlatList
            data={filtered}
            keyExtractor={(item) => item.iso2}
            keyboardShouldPersistTaps="handled"
            renderItem={({ item }) => (
              <Pressable
                onPress={() => {
                  onChange(item);
                  setQuery("");
                  setOpen(false);
                }}
                style={styles.row}
              >
                <Text style={styles.rowFlag}>{flagEmoji(item.iso2)}</Text>
                <Text style={styles.rowName}>{item.name}</Text>
                <Text style={styles.rowDialCode}>{item.dialCode}</Text>
              </Pressable>
            )}
          />
          <Pressable onPress={() => setOpen(false)} style={styles.closeButton}>
            <Text style={styles.closeButtonText}>Cancel</Text>
          </Pressable>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  trigger: {
    borderWidth: 1,
    borderColor: "#ccc",
    borderRadius: 8,
    paddingVertical: 12,
    paddingHorizontal: 14,
    justifyContent: "center",
  },
  triggerText: { fontSize: 16, color: "#111" },
  modal: { flex: 1, backgroundColor: "#fff", padding: 24, paddingTop: 64, gap: 12 },
  modalTitle: { fontSize: 18, fontWeight: "600", textAlign: "center" },
  search: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12, fontSize: 16 },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: "#eee",
  },
  rowFlag: { fontSize: 20 },
  rowName: { flex: 1, fontSize: 16, color: "#111" },
  rowDialCode: { fontSize: 16, color: "#666" },
  closeButton: { alignItems: "center", padding: 14 },
  closeButtonText: { color: "#111", fontWeight: "600" },
});
