import { useCallback, useEffect, useMemo, useState } from "react";
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  ActivityIndicator,
  ScrollView,
  Modal,
  TextInput,
} from "react-native";
import { api } from "../../../lib/api";
import { useAuth } from "../../../lib/auth-context";
import { useOrganizerData } from "../../../lib/organizer-context";
import type {
  EventGroupWithRoadmap,
  TaskWithDependencies,
  BudgetCategoryMutationResponse,
  BudgetCategory,
} from "@sanchalan/shared-types";

export default function EventHomeScreen() {
  const { signOut } = useAuth();
  const { eventGroupId } = useOrganizerData() as { eventGroupId: string };

  const [eventGroup, setEventGroup] = useState<EventGroupWithRoadmap | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [generating, setGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [budgetWarning, setBudgetWarning] = useState<string | null>(null);

  const [editingCategory, setEditingCategory] = useState<BudgetCategory | null>(null);
  const [editAmount, setEditAmount] = useState("");
  const [editSaving, setEditSaving] = useState(false);
  const [editError, setEditError] = useState<string | null>(null);

  const [addingCategory, setAddingCategory] = useState(false);
  const [newCategoryKey, setNewCategoryKey] = useState("");
  const [newCategoryAmount, setNewCategoryAmount] = useState("");
  const [addSaving, setAddSaving] = useState(false);
  const [addError, setAddError] = useState<string | null>(null);

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

  function openEditModal(bc: BudgetCategory) {
    setEditingCategory(bc);
    setEditAmount(String(bc.allocatedAmount));
    setEditError(null);
  }

  async function handleSaveEdit() {
    if (!editingCategory || editSaving) return;
    const amount = Number(editAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
      setEditError("Enter a valid amount.");
      return;
    }
    setEditSaving(true);
    setEditError(null);
    try {
      const { data } = await api.patch<BudgetCategoryMutationResponse>(
        `/event-groups/${eventGroupId}/budget-categories/${editingCategory.id}`,
        { allocatedAmount: amount }
      );
      setBudgetWarning(data.warning);
      setEditingCategory(null);
      await load();
    } catch {
      setEditError("Could not save. Please try again.");
    } finally {
      setEditSaving(false);
    }
  }

  function openAddModal() {
    setNewCategoryKey("");
    setNewCategoryAmount("");
    setAddError(null);
    setAddingCategory(true);
  }

  async function handleSaveAdd() {
    if (addSaving) return;
    const key = newCategoryKey.trim().toLowerCase().replace(/\s+/g, "_");
    const amount = Number(newCategoryAmount);
    if (!key) {
      setAddError("Enter a category name.");
      return;
    }
    if (!Number.isFinite(amount) || amount <= 0) {
      setAddError("Enter a valid amount.");
      return;
    }
    setAddSaving(true);
    setAddError(null);
    try {
      const { data } = await api.post<BudgetCategoryMutationResponse>(
        `/event-groups/${eventGroupId}/budget-categories`,
        { categoryKey: key, allocatedAmount: amount }
      );
      setBudgetWarning(data.warning);
      setAddingCategory(false);
      await load();
    } catch (err: any) {
      setAddError(err?.response?.data?.error ?? "Could not add category. Please try again.");
    } finally {
      setAddSaving(false);
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
        <Pressable key={bc.id} onPress={() => openEditModal(bc)} style={styles.budgetRow}>
          <Text style={styles.budgetLabel}>{bc.categoryKey}</Text>
          <Text style={styles.budgetAmount}>{bc.allocatedAmount.toLocaleString()}</Text>
        </Pressable>
      ))}
      <Pressable onPress={openAddModal}>
        <Text style={styles.addCategoryText}>+ Add category</Text>
      </Pressable>
      {budgetWarning ? <Text style={styles.warning}>{budgetWarning}</Text> : null}

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

      <Modal
        visible={editingCategory !== null}
        animationType="slide"
        onRequestClose={() => setEditingCategory(null)}
      >
        <View style={styles.modal}>
          <Text style={styles.modalTitle}>Edit {editingCategory?.categoryKey}</Text>
          <TextInput
            value={editAmount}
            onChangeText={setEditAmount}
            keyboardType="decimal-pad"
            autoFocus
            style={styles.input}
          />
          {editError ? <Text style={styles.error}>{editError}</Text> : null}
          <Pressable
            onPress={handleSaveEdit}
            disabled={editSaving}
            style={[styles.button, editSaving && styles.buttonDisabled]}
          >
            {editSaving ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Save</Text>}
          </Pressable>
          <Pressable onPress={() => setEditingCategory(null)} style={styles.closeButton}>
            <Text style={styles.closeButtonText}>Cancel</Text>
          </Pressable>
        </View>
      </Modal>

      <Modal
        visible={addingCategory}
        animationType="slide"
        onRequestClose={() => setAddingCategory(false)}
      >
        <View style={styles.modal}>
          <Text style={styles.modalTitle}>Add budget category</Text>
          <TextInput
            value={newCategoryKey}
            onChangeText={setNewCategoryKey}
            placeholder="e.g. gifts"
            autoFocus
            style={styles.input}
          />
          <TextInput
            value={newCategoryAmount}
            onChangeText={setNewCategoryAmount}
            placeholder="Amount"
            keyboardType="decimal-pad"
            style={styles.input}
          />
          {addError ? <Text style={styles.error}>{addError}</Text> : null}
          <Pressable
            onPress={handleSaveAdd}
            disabled={addSaving}
            style={[styles.button, addSaving && styles.buttonDisabled]}
          >
            {addSaving ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Add</Text>}
          </Pressable>
          <Pressable onPress={() => setAddingCategory(false)} style={styles.closeButton}>
            <Text style={styles.closeButtonText}>Cancel</Text>
          </Pressable>
        </View>
      </Modal>
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
  addCategoryText: { fontSize: 14, color: "#111", fontWeight: "600", marginTop: 8 },
  warning: { color: "#c00", fontSize: 14, marginTop: 8 },
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
  modal: { flex: 1, backgroundColor: "#fff", padding: 24, paddingTop: 64, gap: 12 },
  modalTitle: { fontSize: 18, fontWeight: "600", textAlign: "center", textTransform: "capitalize" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12, fontSize: 16 },
  closeButton: { alignItems: "center", padding: 14 },
  closeButtonText: { color: "#111", fontWeight: "600" },
});
