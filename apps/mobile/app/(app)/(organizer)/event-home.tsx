import { useCallback, useEffect, useMemo, useState } from "react";
import { View, Text, Pressable, StyleSheet, ActivityIndicator, ScrollView } from "react-native";
import { api } from "../../../lib/api";
import { useAuth } from "../../../lib/auth-context";
import { useOrganizerData } from "../../../lib/organizer-context";
import type { EventGroupWithRoadmap, TaskWithDependencies } from "@sanchalan/shared-types";

export default function EventHomeScreen() {
  const { signOut } = useAuth();
  const { eventGroupId } = useOrganizerData() as { eventGroupId: string };

  const [eventGroup, setEventGroup] = useState<EventGroupWithRoadmap | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [generating, setGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const { data } = await api.get<EventGroupWithRoadmap>(`/event-groups/${eventGroupId}`);
      setEventGroup(data);
    } catch {
      setError("Could not load your event.");
    }
  }, [eventGroupId]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleGenerateRoadmap() {
    if (generating) return;
    setGenerating(true);
    setGenerateError(null);
    try {
      await api.post(`/event-groups/${eventGroupId}/generate-roadmap`);
      await load();
    } catch {
      setGenerateError("Could not generate your roadmap. Please try again.");
    } finally {
      setGenerating(false);
    }
  }

  const groupedTasks = useMemo(() => {
    if (!eventGroup) return [];
    const groups = new Map<string, TaskWithDependencies[]>();
    for (const task of eventGroup.tasks) {
      const list = groups.get(task.categoryKey) ?? [];
      list.push(task);
      groups.set(task.categoryKey, list);
    }
    return Array.from(groups.entries())
      .map(([categoryKey, tasks]) => ({
        categoryKey,
        tasks: [...tasks].sort((a, b) => (a.dueDate ?? "").localeCompare(b.dueDate ?? "")),
      }))
      .sort((a, b) => a.categoryKey.localeCompare(b.categoryKey));
  }, [eventGroup]);

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.error}>{error}</Text>
      </View>
    );
  }

  if (!eventGroup) {
    return (
      <View style={styles.center}>
        <ActivityIndicator />
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{eventGroup.name}</Text>
      <Text style={styles.subtitle}>{eventGroup.primaryDate}</Text>

      <Text style={styles.sectionTitle}>Budget breakdown</Text>
      {eventGroup.budgetCategories.map((bc) => (
        <View key={bc.id} style={styles.budgetRow}>
          <Text style={styles.budgetLabel}>{bc.categoryKey}</Text>
          <Text style={styles.budgetAmount}>{bc.allocatedAmount.toLocaleString()}</Text>
        </View>
      ))}

      <Text style={styles.sectionTitle}>Roadmap</Text>
      {eventGroup.tasks.length === 0 ? (
        <>
          {generateError ? <Text style={styles.error}>{generateError}</Text> : null}
          <Pressable
            onPress={handleGenerateRoadmap}
            disabled={generating}
            style={[styles.button, generating && styles.buttonDisabled]}
          >
            {generating ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.buttonText}>Generate my roadmap</Text>
            )}
          </Pressable>
        </>
      ) : (
        groupedTasks.map((group) => (
          <View key={group.categoryKey} style={styles.categoryGroup}>
            <Text style={styles.categoryHeader}>{group.categoryKey}</Text>
            {group.tasks.map((task) => (
              <View key={task.id} style={styles.taskRow}>
                <Text style={styles.taskName}>{task.name}</Text>
                <Text style={styles.taskDueDate}>{task.dueDate ?? "—"}</Text>
              </View>
            ))}
          </View>
        ))
      )}

      <Pressable onPress={signOut} style={[styles.button, styles.logoutButton]}>
        <Text style={styles.buttonText}>Log out</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { backgroundColor: "#fff", padding: 24, gap: 12 },
  center: { flex: 1, backgroundColor: "#fff", alignItems: "center", justifyContent: "center" },
  title: { fontSize: 22, fontWeight: "600" },
  subtitle: { fontSize: 16, color: "#666" },
  sectionTitle: { fontSize: 16, fontWeight: "600", marginTop: 16 },
  budgetRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: "#ccc",
  },
  budgetLabel: { fontSize: 16, textTransform: "capitalize" },
  budgetAmount: { fontSize: 16, fontWeight: "600" },
  categoryGroup: { marginTop: 8 },
  categoryHeader: {
    fontSize: 14,
    fontWeight: "600",
    color: "#666",
    textTransform: "capitalize",
    marginBottom: 4,
  },
  taskRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: "#ccc",
  },
  taskName: { fontSize: 16, flex: 1, marginRight: 12 },
  taskDueDate: { fontSize: 14, color: "#666" },
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center", marginTop: 8 },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontWeight: "600" },
  logoutButton: { marginTop: 24 },
});
