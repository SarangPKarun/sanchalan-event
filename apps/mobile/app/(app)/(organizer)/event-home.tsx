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
  Platform,
  Alert,
} from "react-native";
import DateTimePicker, { DateTimePickerAndroid } from "@react-native-community/datetimepicker";
import { router, useLocalSearchParams } from "expo-router";
import { api } from "../../../lib/api";
import { useOrganizerData } from "../../../lib/organizer-context";
import { EditEventModal } from "../../../lib/EditEventModal";
import { RegenerateRoadmapModal } from "../../../lib/RegenerateRoadmapModal";
import type {
  EventGroupWithRoadmap,
  TaskWithFullDependencies,
  ListEventGroupTasksResponse,
  BudgetCategoryMutationResponse,
  DeleteBudgetCategoryResponse,
  UpdateBudgetCategoryBody,
  UpdateEventGroupResponse,
  GenerateRoadmapResponse,
  TaskCategorySummary,
  BudgetCategory,
} from "@sanchalan/shared-types";

// Category keys are snake_case ("music_entertainment"); show them as plain words.
function labelOf(key: string): string {
  return key.replace(/_/g, " ");
}

function toDateOnly(d: Date): string {
  return d.toISOString().slice(0, 10);
}

const NORMAL_STATUSES = ["not_started", "in_progress", "done"] as const;
type NormalStatus = (typeof NORMAL_STATUSES)[number];
const TASK_STATUSES: { value: NormalStatus; label: string }[] = [
  { value: "not_started", label: "Not started" },
  { value: "in_progress", label: "In progress" },
  { value: "done", label: "Done" },
];

export default function EventHomeScreen() {
  const { eventGroupId } = useLocalSearchParams<{ eventGroupId: string }>();
  const { reloadEvents } = useOrganizerData();

  const [eventGroup, setEventGroup] = useState<EventGroupWithRoadmap | null>(null);
  const [tasks, setTasks] = useState<TaskWithFullDependencies[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [generating, setGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [budgetWarning, setBudgetWarning] = useState<string | null>(null);

  const [editingEvent, setEditingEvent] = useState(false);
  const [regenerating, setRegenerating] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [taskCategories, setTaskCategories] = useState<TaskCategorySummary[]>([]);
  const [showRemoved, setShowRemoved] = useState(false);
  const [removedTasks, setRemovedTasks] = useState<TaskWithFullDependencies[]>([]);

  const [editingCategory, setEditingCategory] = useState<BudgetCategory | null>(null);
  const [editCategoryKey, setEditCategoryKey] = useState("");
  const [editAmount, setEditAmount] = useState("");
  const [editSaving, setEditSaving] = useState(false);
  const [editError, setEditError] = useState<string | null>(null);

  const [addingCategory, setAddingCategory] = useState(false);
  const [newCategoryKey, setNewCategoryKey] = useState("");
  const [newCategoryAmount, setNewCategoryAmount] = useState("");
  const [addSaving, setAddSaving] = useState(false);
  const [addError, setAddError] = useState<string | null>(null);

  const [selectedTask, setSelectedTask] = useState<TaskWithFullDependencies | null>(null);
  const [editTaskName, setEditTaskName] = useState("");
  const [editTaskDescription, setEditTaskDescription] = useState("");
  const [editTaskDueDate, setEditTaskDueDate] = useState<Date | null>(null);
  const [editTaskStatus, setEditTaskStatus] = useState<NormalStatus>("not_started");
  const [editTaskCategory, setEditTaskCategory] = useState("");
  const [showEditIosPicker, setShowEditIosPicker] = useState(false);
  const [taskSaving, setTaskSaving] = useState(false);
  const [taskSaveError, setTaskSaveError] = useState<string | null>(null);

  const [addingTask, setAddingTask] = useState(false);
  const [newTaskName, setNewTaskName] = useState("");
  const [newTaskCategory, setNewTaskCategory] = useState("");
  const [newTaskDueDate, setNewTaskDueDate] = useState<Date | null>(null);
  const [showAddIosPicker, setShowAddIosPicker] = useState(false);
  const [addTaskSaving, setAddTaskSaving] = useState(false);
  const [addTaskError, setAddTaskError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const { data } = await api.get<EventGroupWithRoadmap>(`/event-groups/${eventGroupId}`);
      setEventGroup(data);
    } catch {
      setError("Could not load your event.");
    }
  }, [eventGroupId]);

  const loadTasks = useCallback(async () => {
    try {
      const { data } = await api.get<ListEventGroupTasksResponse>(
        `/event-groups/${eventGroupId}/tasks`
      );
      setTasks(data.tasks);
    } catch {
      // Keep whatever task list we already have on a transient failure —
      // the main `error` state already covers the primary event load.
    }
  }, [eventGroupId]);

  const loadRemovedTasks = useCallback(async () => {
    try {
      const { data } = await api.get<ListEventGroupTasksResponse>(
        `/event-groups/${eventGroupId}/tasks?includeNotApplicable=true`
      );
      setRemovedTasks(data.tasks.filter((t) => t.status === "not_applicable"));
    } catch {
      // Non-critical list; leave whatever we had.
    }
  }, [eventGroupId]);

  useEffect(() => {
    load();
    loadTasks();
    api
      .get<{ categories: TaskCategorySummary[] }>("/task-categories")
      .then(({ data }) => setTaskCategories(data.categories))
      .catch(() => {});
  }, [load, loadTasks]);

  useEffect(() => {
    if (showRemoved) loadRemovedTasks();
  }, [showRemoved, loadRemovedTasks]);

  async function handleGenerateRoadmap() {
    if (generating) return;
    setGenerating(true);
    setGenerateError(null);
    try {
      await api.post(`/event-groups/${eventGroupId}/generate-roadmap`, undefined, {
        timeout: 90_000, // LLM generation can exceed the client's default timeout
      });
      await load();
      await loadTasks();
    } catch {
      setGenerateError("Could not generate your roadmap. Please try again.");
    } finally {
      setGenerating(false);
    }
  }

  async function handleEventSaved(result: UpdateEventGroupResponse) {
    setEditingEvent(false);
    setBudgetWarning(result.warning);
    setNotice(null);
    await load();
  }

  async function handleRegenerated(result: GenerateRoadmapResponse) {
    setRegenerating(false);
    setNotice(
      `Roadmap updated: ${result.tasks.length} task${result.tasks.length === 1 ? "" : "s"} added` +
        `${result.removedTaskCount ? `, ${result.removedTaskCount} removed` : ""}.`
    );
    await load();
    await loadTasks();
    if (showRemoved) await loadRemovedTasks();
  }

  async function handleRestoreTask(task: TaskWithFullDependencies) {
    try {
      await api.patch(`/tasks/${task.id}`, { status: "not_started" });
      await loadTasks();
      await loadRemovedTasks();
    } catch {
      Alert.alert("Could not restore", "Please try again.");
    }
  }

  function handleDeleteEvent() {
    if (!eventGroup || deleting) return;
    Alert.alert(
      "Delete this event?",
      `"${eventGroup.name}" and its budget, roadmap and tasks will be permanently deleted. This can't be undone.`,
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete event",
          style: "destructive",
          onPress: async () => {
            setDeleting(true);
            try {
              await api.delete(`/event-groups/${eventGroupId}`);
              await reloadEvents();
              // Back to the existing "My events" screen (don't stack a second copy of it).
              router.canGoBack()
                ? router.back()
                : router.replace({ pathname: "/(app)/(organizer)/events" });
            } catch (err: any) {
              setDeleting(false);
              Alert.alert(
                "Could not delete the event",
                err?.response?.data?.error ?? "Please try again."
              );
            }
          },
        },
      ]
    );
  }

  function openEditModal(bc: BudgetCategory) {
    setEditingCategory(bc);
    setEditCategoryKey(bc.categoryKey);
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
    const key = editCategoryKey.trim().toLowerCase().replace(/\s+/g, "_");
    if (!key) {
      setEditError("Enter a category name.");
      return;
    }
    const body: UpdateBudgetCategoryBody = {};
    if (amount !== editingCategory.allocatedAmount) body.allocatedAmount = amount;
    if (key !== editingCategory.categoryKey) body.categoryKey = key;
    if (Object.keys(body).length === 0) {
      setEditingCategory(null);
      return;
    }
    setEditSaving(true);
    setEditError(null);
    try {
      const { data } = await api.patch<BudgetCategoryMutationResponse>(
        `/event-groups/${eventGroupId}/budget-categories/${editingCategory.id}`,
        body
      );
      setBudgetWarning(data.warning);
      setEditingCategory(null);
      await load();
    } catch (err: any) {
      setEditError(err?.response?.data?.error ?? "Could not save. Please try again.");
    } finally {
      setEditSaving(false);
    }
  }

  function handleDeleteCategory() {
    if (!editingCategory) return;
    const target = editingCategory;
    Alert.alert(
      "Delete category",
      `Delete "${labelOf(target.categoryKey)}" and its ${target.allocatedAmount.toLocaleString()} allocation?`,
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: async () => {
            setEditSaving(true);
            setEditError(null);
            try {
              const { data } = await api.delete<DeleteBudgetCategoryResponse>(
                `/event-groups/${eventGroupId}/budget-categories/${target.id}`
              );
              setBudgetWarning(data.warning);
              setEditingCategory(null);
              await load();
            } catch (err: any) {
              setEditError(err?.response?.data?.error ?? "Could not delete. Please try again.");
            } finally {
              setEditSaving(false);
            }
          },
        },
      ]
    );
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

  function openTaskDetail(task: TaskWithFullDependencies) {
    setSelectedTask(task);
    setEditTaskName(task.name);
    setEditTaskDescription(task.description ?? "");
    setEditTaskDueDate(task.dueDate ? new Date(task.dueDate) : null);
    setEditTaskStatus(
      (NORMAL_STATUSES as readonly string[]).includes(task.status)
        ? (task.status as NormalStatus)
        : "not_started"
    );
    setEditTaskCategory(task.categoryKey);
    setTaskSaveError(null);
  }

  function openTaskDueDatePicker() {
    if (Platform.OS === "android") {
      DateTimePickerAndroid.open({
        value: editTaskDueDate ?? new Date(),
        mode: "date",
        onValueChange: (_event, selected) => {
          setEditTaskDueDate(selected);
        },
      });
    } else {
      setShowEditIosPicker(true);
    }
  }

  async function handleSaveTask() {
    if (!selectedTask || taskSaving) return;
    if (!editTaskName.trim()) {
      setTaskSaveError("Enter a task name.");
      return;
    }
    setTaskSaving(true);
    setTaskSaveError(null);
    try {
      await api.patch(`/tasks/${selectedTask.id}`, {
        status: editTaskStatus,
        dueDate: editTaskDueDate ? toDateOnly(editTaskDueDate) : null,
        name: editTaskName.trim(),
        description: editTaskDescription.trim() || null,
        ...(editTaskCategory !== selectedTask.categoryKey ? { category: editTaskCategory } : {}),
      });
      setSelectedTask(null);
      await loadTasks();
    } catch {
      setTaskSaveError("Could not save. Please try again.");
    } finally {
      setTaskSaving(false);
    }
  }

  async function handleMarkNotApplicable() {
    if (!selectedTask || taskSaving) return;
    setTaskSaving(true);
    setTaskSaveError(null);
    try {
      await api.delete(`/tasks/${selectedTask.id}`);
      setSelectedTask(null);
      await loadTasks();
      if (showRemoved) await loadRemovedTasks();
    } catch {
      setTaskSaveError("Could not update. Please try again.");
    } finally {
      setTaskSaving(false);
    }
  }

  function openAddTaskModal() {
    setNewTaskName("");
    setNewTaskCategory(taskCategories[0]?.categoryKey ?? "");
    setNewTaskDueDate(null);
    setAddTaskError(null);
    setAddingTask(true);
  }

  function openNewTaskDueDatePicker() {
    if (Platform.OS === "android") {
      DateTimePickerAndroid.open({
        value: newTaskDueDate ?? new Date(),
        mode: "date",
        onValueChange: (_event, selected) => {
          setNewTaskDueDate(selected);
        },
      });
    } else {
      setShowAddIosPicker(true);
    }
  }

  async function handleSaveNewTask() {
    if (addTaskSaving) return;
    if (!newTaskName.trim()) {
      setAddTaskError("Enter a task name.");
      return;
    }
    if (!newTaskCategory) {
      setAddTaskError("Choose a category.");
      return;
    }
    if (!newTaskDueDate) {
      setAddTaskError("Choose a due date.");
      return;
    }
    setAddTaskSaving(true);
    setAddTaskError(null);
    try {
      await api.post(`/event-groups/${eventGroupId}/tasks`, {
        name: newTaskName.trim(),
        category: newTaskCategory,
        dueDate: toDateOnly(newTaskDueDate),
      });
      setAddingTask(false);
      await loadTasks();
    } catch (err: any) {
      setAddTaskError(err?.response?.data?.error ?? "Could not add task. Please try again.");
    } finally {
      setAddTaskSaving(false);
    }
  }

  const allocatedTotal = useMemo(
    () => (eventGroup?.budgetCategories ?? []).reduce((sum, c) => sum + c.allocatedAmount, 0),
    [eventGroup]
  );
  const remaining = (eventGroup?.totalBudget ?? 0) - allocatedTotal;

  const groupedTasks = useMemo(() => {
    const groups = new Map<string, TaskWithFullDependencies[]>();
    for (const task of tasks) {
      const list = groups.get(task.categoryKey) ?? [];
      list.push(task);
      groups.set(task.categoryKey, list);
    }
    return Array.from(groups.entries())
      .map(([categoryKey, categoryTasks]) => ({
        categoryKey,
        tasks: [...categoryTasks].sort((a, b) => (a.dueDate ?? "").localeCompare(b.dueDate ?? "")),
      }))
      .sort((a, b) => a.categoryKey.localeCompare(b.categoryKey));
  }, [tasks]);

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
      <View style={styles.topBar}>
        <Pressable
          onPress={() =>
            router.canGoBack() ? router.back() : router.replace({ pathname: "/(app)/(organizer)/events" })
          }
        >
          <Text style={styles.addCategoryText}>‹ My events</Text>
        </Pressable>
        <Pressable onPress={() => router.push({ pathname: "/(app)/(organizer)/event-setup" })}>
          <Text style={styles.addCategoryText}>+ Add event</Text>
        </Pressable>
      </View>
      <Text style={styles.title}>{eventGroup.name}</Text>
      <Text style={styles.subtitle}>
        {eventGroup.primaryDate} · {eventGroup.guestCountEstimate} guests · {eventGroup.budgetTier}
      </Text>
      <Pressable onPress={() => setEditingEvent(true)} style={styles.editIconRow}>
        <Text style={styles.editIcon}>✏️</Text>
        <Text style={styles.addCategoryText}>Edit event details</Text>
      </Pressable>

      <Pressable
        onPress={() =>
          router.push({ pathname: "/(app)/(organizer)/vendors", params: { eventGroupId } })
        }
        style={[styles.button, styles.browseVendorsButton]}
      >
        <Text style={styles.buttonText}>Browse vendors</Text>
      </Pressable>

      <Text style={styles.sectionTitle}>Budget breakdown</Text>
      <View style={styles.summaryBox}>
        <Pressable
          onPress={() => setEditingEvent(true)}
          style={styles.summaryRow}
          accessibilityLabel="Edit total budget"
        >
          <Text style={styles.budgetLabel}>Total budget</Text>
          <View style={styles.editIconRow}>
            <Text style={styles.totalAmount}>{eventGroup.totalBudget.toLocaleString()}</Text>
            <Text style={styles.editIcon}>✏️</Text>
          </View>
        </Pressable>
        <View style={styles.summaryRow}>
          <Text style={styles.budgetLabel}>Allocated</Text>
          <Text style={styles.budgetAmount}>{allocatedTotal.toLocaleString()}</Text>
        </View>
        <View style={styles.summaryRow}>
          <Text style={styles.budgetLabel}>{remaining < 0 ? "Over by" : "Remaining"}</Text>
          <Text style={[styles.budgetAmount, remaining < 0 && styles.overBudget]}>
            {Math.abs(remaining).toLocaleString()}
          </Text>
        </View>
      </View>
      {eventGroup.budgetCategories.map((bc) => (
        <Pressable key={bc.id} onPress={() => openEditModal(bc)} style={styles.budgetRow}>
          <Text style={styles.budgetLabel}>{labelOf(bc.categoryKey)}</Text>
          <View style={styles.editIconRow}>
            <Text style={styles.budgetAmount}>{bc.allocatedAmount.toLocaleString()}</Text>
            <Text style={styles.editIcon}>✏️</Text>
          </View>
        </Pressable>
      ))}
      <Pressable onPress={openAddModal}>
        <Text style={styles.addCategoryText}>+ Add category</Text>
      </Pressable>
      {budgetWarning ? <Text style={styles.warning}>{budgetWarning}</Text> : null}

      <Text style={styles.sectionTitle}>Roadmap</Text>
      <Pressable onPress={openAddTaskModal}>
        <Text style={styles.addCategoryText}>+ Add task</Text>
      </Pressable>
      {notice ? <Text style={styles.notice}>{notice}</Text> : null}
      {eventGroup.tasks.length > 0 ? (
        <Pressable onPress={() => setRegenerating(true)} style={[styles.button, styles.outlineButton]}>
          <Text style={styles.outlineButtonText}>🔄 Re-run roadmap</Text>
        </Pressable>
      ) : null}
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
            <Text style={styles.categoryHeader}>{labelOf(group.categoryKey)}</Text>
            {group.tasks.map((task) => (
              <Pressable key={task.id} onPress={() => openTaskDetail(task)} style={styles.taskRow}>
                <Text style={styles.taskName}>{task.name}</Text>
                <Text style={styles.taskDueDate}>{task.dueDate ?? "—"}</Text>
              </Pressable>
            ))}
          </View>
        ))
      )}

      {eventGroup.tasks.length > 0 ? (
        <View style={styles.categoryGroup}>
          <Pressable onPress={() => setShowRemoved((v) => !v)}>
            <Text style={styles.addCategoryText}>
              {showRemoved ? "Hide removed tasks" : "Show removed tasks"}
            </Text>
          </Pressable>
          {showRemoved
            ? removedTasks.length === 0
              ? <Text style={styles.taskDueDate}>No removed tasks.</Text>
              : removedTasks.map((task) => (
                  <View key={task.id} style={styles.taskRow}>
                    <Text style={[styles.taskName, styles.removedTask]}>{task.name}</Text>
                    <Pressable onPress={() => handleRestoreTask(task)}>
                      <Text style={styles.addCategoryText}>Restore</Text>
                    </Pressable>
                  </View>
                ))
            : null}
        </View>
      ) : null}

      <Pressable
        onPress={handleDeleteEvent}
        disabled={deleting}
        style={[styles.deleteEventButton, deleting && styles.buttonDisabled]}
      >
        {deleting ? (
          <ActivityIndicator color="#c00" />
        ) : (
          <Text style={styles.deleteEventText}>🗑️ Delete event</Text>
        )}
      </Pressable>

      <Modal
        visible={editingCategory !== null}
        animationType="slide"
        onRequestClose={() => setEditingCategory(null)}
      >
        <View style={styles.modal}>
          <Text style={styles.modalTitle}>Edit {labelOf(editingCategory?.categoryKey ?? "")}</Text>
          <TextInput
            value={editCategoryKey}
            onChangeText={setEditCategoryKey}
            placeholder="Category name"
            style={styles.input}
          />
          <TextInput
            value={editAmount}
            onChangeText={setEditAmount}
            placeholder="Amount"
            keyboardType="decimal-pad"
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
          <Pressable onPress={handleDeleteCategory} disabled={editSaving} style={styles.closeButton}>
            <Text style={styles.dismissText}>Delete category</Text>
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

      <Modal
        visible={selectedTask !== null}
        animationType="slide"
        onRequestClose={() => setSelectedTask(null)}
      >
        <ScrollView contentContainerStyle={styles.modal}>
          <Text style={styles.modalTitle}>Task</Text>
          <TextInput
            value={editTaskName}
            onChangeText={setEditTaskName}
            placeholder="Task name"
            autoFocus
            style={styles.input}
          />
          <TextInput
            value={editTaskDescription}
            onChangeText={setEditTaskDescription}
            placeholder="Description (optional)"
            multiline
            style={[styles.input, styles.inputMultiline]}
          />
          <Pressable onPress={openTaskDueDatePicker} style={styles.input}>
            <Text style={editTaskDueDate ? styles.dateText : styles.datePlaceholder}>
              {editTaskDueDate ? toDateOnly(editTaskDueDate) : "No due date"}
            </Text>
          </Pressable>
          {Platform.OS === "ios" && showEditIosPicker && (
            <DateTimePicker
              value={editTaskDueDate ?? new Date()}
              mode="date"
              display="inline"
              onValueChange={(_event, selected) => {
                setShowEditIosPicker(false);
                setEditTaskDueDate(selected);
              }}
              onDismiss={() => setShowEditIosPicker(false)}
            />
          )}
          <View style={styles.chipRow}>
            {taskCategories.map((c) => (
              <Pressable
                key={c.id}
                onPress={() => setEditTaskCategory(c.categoryKey)}
                style={[styles.chip, editTaskCategory === c.categoryKey && styles.chipActive]}
              >
                <Text
                  style={editTaskCategory === c.categoryKey ? styles.chipTextActive : styles.chipText}
                >
                  {labelOf(c.categoryKey)}
                </Text>
              </Pressable>
            ))}
          </View>
          <View style={styles.chipRow}>
            {TASK_STATUSES.map((opt) => (
              <Pressable
                key={opt.value}
                onPress={() => setEditTaskStatus(opt.value)}
                style={[styles.chip, editTaskStatus === opt.value && styles.chipActive]}
              >
                <Text style={editTaskStatus === opt.value ? styles.chipTextActive : styles.chipText}>
                  {opt.label}
                </Text>
              </Pressable>
            ))}
          </View>
          {taskSaveError ? <Text style={styles.error}>{taskSaveError}</Text> : null}
          <Pressable
            onPress={handleSaveTask}
            disabled={taskSaving}
            style={[styles.button, taskSaving && styles.buttonDisabled]}
          >
            {taskSaving ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Save</Text>}
          </Pressable>
          <Pressable
            onPress={handleMarkNotApplicable}
            disabled={taskSaving}
            style={styles.closeButton}
          >
            <Text style={styles.dismissText}>Mark as not applicable</Text>
          </Pressable>
          <Pressable onPress={() => setSelectedTask(null)} style={styles.closeButton}>
            <Text style={styles.closeButtonText}>Cancel</Text>
          </Pressable>
        </ScrollView>
      </Modal>

      <Modal
        visible={addingTask}
        animationType="slide"
        onRequestClose={() => setAddingTask(false)}
      >
        <ScrollView contentContainerStyle={styles.modal}>
          <Text style={styles.modalTitle}>Add task</Text>
          <TextInput
            value={newTaskName}
            onChangeText={setNewTaskName}
            placeholder="Task name"
            autoFocus
            style={styles.input}
          />
          <View style={styles.chipRow}>
            {taskCategories.map((c) => (
              <Pressable
                key={c.id}
                onPress={() => setNewTaskCategory(c.categoryKey)}
                style={[styles.chip, newTaskCategory === c.categoryKey && styles.chipActive]}
              >
                <Text
                  style={newTaskCategory === c.categoryKey ? styles.chipTextActive : styles.chipText}
                >
                  {labelOf(c.categoryKey)}
                </Text>
              </Pressable>
            ))}
          </View>
          <Pressable onPress={openNewTaskDueDatePicker} style={styles.input}>
            <Text style={newTaskDueDate ? styles.dateText : styles.datePlaceholder}>
              {newTaskDueDate ? toDateOnly(newTaskDueDate) : "Select a due date"}
            </Text>
          </Pressable>
          {Platform.OS === "ios" && showAddIosPicker && (
            <DateTimePicker
              value={newTaskDueDate ?? new Date()}
              mode="date"
              display="inline"
              onValueChange={(_event, selected) => {
                setShowAddIosPicker(false);
                setNewTaskDueDate(selected);
              }}
              onDismiss={() => setShowAddIosPicker(false)}
            />
          )}
          {addTaskError ? <Text style={styles.error}>{addTaskError}</Text> : null}
          <Pressable
            onPress={handleSaveNewTask}
            disabled={addTaskSaving}
            style={[styles.button, addTaskSaving && styles.buttonDisabled]}
          >
            {addTaskSaving ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Add</Text>}
          </Pressable>
          <Pressable onPress={() => setAddingTask(false)} style={styles.closeButton}>
            <Text style={styles.closeButtonText}>Cancel</Text>
          </Pressable>
        </ScrollView>
      </Modal>

      <EditEventModal
        visible={editingEvent}
        eventGroup={eventGroup}
        onClose={() => setEditingEvent(false)}
        onSaved={handleEventSaved}
      />
      <RegenerateRoadmapModal
        visible={regenerating}
        eventGroupId={eventGroupId}
        onClose={() => setRegenerating(false)}
        onDone={handleRegenerated}
      />
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
  editIconRow: { flexDirection: "row", alignItems: "center", gap: 8 },
  editIcon: { fontSize: 16 },
  totalAmount: { fontSize: 18, fontWeight: "700" },
  outlineButton: { backgroundColor: "#fff", borderWidth: 1, borderColor: "#111" },
  outlineButtonText: { color: "#111", fontWeight: "600" },
  notice: { color: "#060", fontSize: 14, marginTop: 4 },
  summaryBox: { gap: 4, padding: 12, borderRadius: 8, backgroundColor: "#f5f5f5" },
  summaryRow: { flexDirection: "row", justifyContent: "space-between" },
  overBudget: { color: "#c00" },
  removedTask: { color: "#999", textDecorationLine: "line-through" },
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
  browseVendorsButton: { marginTop: 4 },
  deleteEventButton: {
    marginTop: 32,
    marginBottom: 24,
    borderWidth: 1,
    borderColor: "#c00",
    borderRadius: 8,
    padding: 14,
    alignItems: "center",
  },
  deleteEventText: { color: "#c00", fontWeight: "600" },
  topBar: { flexDirection: "row", justifyContent: "space-between", marginTop: 40 },
  modal: { flexGrow: 1, backgroundColor: "#fff", padding: 24, paddingTop: 64, gap: 12 },
  modalTitle: { fontSize: 18, fontWeight: "600", textAlign: "center", textTransform: "capitalize" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12, fontSize: 16 },
  inputMultiline: { minHeight: 80, textAlignVertical: "top" },
  dateText: { fontSize: 16, color: "#111" },
  datePlaceholder: { fontSize: 16, color: "#999" },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { paddingVertical: 8, paddingHorizontal: 14, borderRadius: 20, borderWidth: 1, borderColor: "#ccc" },
  chipActive: { backgroundColor: "#111", borderColor: "#111" },
  chipText: { color: "#111" },
  chipTextActive: { color: "#fff" },
  closeButton: { alignItems: "center", padding: 14 },
  closeButtonText: { color: "#111", fontWeight: "600" },
  dismissText: { color: "#c00", fontWeight: "600" },
});
