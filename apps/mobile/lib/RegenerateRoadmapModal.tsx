import { useEffect, useState } from "react";
import { View, Text, Pressable, StyleSheet, ActivityIndicator, ScrollView, Modal } from "react-native";
import { api } from "./api";
import type {
  GenerateRoadmapBody,
  GenerateRoadmapResponse,
  RoadmapRegenMode,
} from "@sanchalan/shared-types";

const MODES: { value: RoadmapRegenMode; title: string; description: string }[] = [
  {
    value: "keep_my_work",
    title: "Keep my work",
    description:
      "Replace only untouched generated tasks. Tasks you added, edited, started or finished are kept.",
  },
  {
    value: "add_missing",
    title: "Add only missing",
    description: "Keep every current task and add only new suggestions that aren't already there.",
  },
  {
    value: "replace_all",
    title: "Replace everything",
    description:
      "Remove all current tasks (including your edits and progress) and generate a fresh roadmap. Removed tasks can be restored.",
  },
];

export function RegenerateRoadmapModal({
  visible,
  eventGroupId,
  onClose,
  onDone,
}: {
  visible: boolean;
  eventGroupId: string;
  onClose: () => void;
  onDone: (result: GenerateRoadmapResponse) => void;
}) {
  const [mode, setMode] = useState<RoadmapRegenMode>("keep_my_work");
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) return;
    setMode("keep_my_work");
    setError(null);
  }, [visible]);

  async function handleRun() {
    if (running) return;
    setRunning(true);
    setError(null);
    try {
      const body: GenerateRoadmapBody = { mode };
      const { data } = await api.post<GenerateRoadmapResponse>(
        `/event-groups/${eventGroupId}/generate-roadmap`,
        body,
        { timeout: 90_000 } // LLM generation can exceed the client's default timeout
      );
      onDone(data);
    } catch (err: any) {
      setError(err?.response?.data?.error ?? "Could not re-run the roadmap. Please try again.");
    } finally {
      setRunning(false);
    }
  }

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={() => !running && onClose()}>
      <ScrollView contentContainerStyle={styles.modal}>
        <Text style={styles.modalTitle}>Re-run roadmap</Text>
        <Text style={styles.intro}>Choose what should happen to your current tasks.</Text>

        {MODES.map((m) => (
          <Pressable
            key={m.value}
            onPress={() => setMode(m.value)}
            disabled={running}
            style={[styles.option, mode === m.value && styles.optionActive]}
          >
            <Text style={[styles.optionTitle, mode === m.value && styles.optionTitleActive]}>
              {m.title}
            </Text>
            <Text style={[styles.optionDescription, mode === m.value && styles.optionTitleActive]}>
              {m.description}
            </Text>
          </Pressable>
        ))}

        {running ? <Text style={styles.hint}>Generating… this can take up to a minute.</Text> : null}
        {error ? <Text style={styles.error}>{error}</Text> : null}

        <Pressable
          onPress={handleRun}
          disabled={running}
          style={[styles.button, running && styles.buttonDisabled]}
        >
          {running ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Re-run roadmap</Text>}
        </Pressable>
        <Pressable onPress={onClose} disabled={running} style={styles.closeButton}>
          <Text style={styles.closeButtonText}>Cancel</Text>
        </Pressable>
      </ScrollView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modal: { flexGrow: 1, backgroundColor: "#fff", padding: 24, paddingTop: 64, gap: 12 },
  modalTitle: { fontSize: 18, fontWeight: "600", textAlign: "center" },
  intro: { fontSize: 14, color: "#666", textAlign: "center" },
  option: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 14, gap: 4 },
  optionActive: { backgroundColor: "#111", borderColor: "#111" },
  optionTitle: { fontSize: 16, fontWeight: "600", color: "#111" },
  optionTitleActive: { color: "#fff" },
  optionDescription: { fontSize: 13, color: "#555" },
  hint: { fontSize: 13, color: "#666", textAlign: "center" },
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center", marginTop: 8 },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontWeight: "600" },
  closeButton: { alignItems: "center", padding: 14 },
  closeButtonText: { color: "#111", fontWeight: "600" },
});
