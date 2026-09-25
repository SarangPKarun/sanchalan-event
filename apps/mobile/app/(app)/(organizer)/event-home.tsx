import { useEffect, useState } from "react";
import { View, Text, Pressable, StyleSheet, ActivityIndicator, ScrollView } from "react-native";
import { api } from "../../../lib/api";
import { useAuth } from "../../../lib/auth-context";
import { useOrganizerData } from "../../../lib/organizer-context";
import type { EventGroupWithDetails } from "@sanchalan/shared-types";

export default function EventHomeScreen() {
  const { signOut } = useAuth();
  const { eventGroupId } = useOrganizerData() as { eventGroupId: string };

  const [eventGroup, setEventGroup] = useState<EventGroupWithDetails | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    api
      .get<EventGroupWithDetails>(`/event-groups/${eventGroupId}`)
      .then(({ data }) => {
        if (!cancelled) setEventGroup(data);
      })
      .catch(() => {
        if (!cancelled) setError("Could not load your event.");
      });
    return () => {
      cancelled = true;
    };
  }, [eventGroupId]);

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

      <Pressable onPress={signOut} style={styles.button}>
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
  error: { color: "#c00", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center", marginTop: 24 },
  buttonText: { color: "#fff", fontWeight: "600" },
});
