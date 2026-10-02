import { useCallback } from "react";
import { View, Text, Pressable, StyleSheet, ScrollView } from "react-native";
import { router, useFocusEffect } from "expo-router";
import { useAuth } from "../../../lib/auth-context";
import { useOrganizerData } from "../../../lib/organizer-context";
import type { EventGroupWithSubEvents } from "@sanchalan/shared-types";

const EVENT_TYPE_LABELS: Record<string, string> = {
  wedding: "Wedding",
  birthday: "Birthday",
  corporate: "Corporate",
  religious: "Religious",
  engagement_only: "Engagement",
  custom: "Custom",
};

function daysUntil(dateOnly: string): number {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(`${dateOnly}T00:00:00`);
  return Math.round((target.getTime() - today.getTime()) / 86_400_000);
}

function whenLabel(dateOnly: string): string {
  const days = daysUntil(dateOnly);
  if (days === 0) return "Today";
  if (days === 1) return "Tomorrow";
  if (days > 1) return `In ${days} days`;
  return "Past event";
}

function EventCard({ event }: { event: EventGroupWithSubEvents }) {
  const past = daysUntil(event.primaryDate) < 0;
  return (
    <Pressable
      onPress={() =>
        router.push({ pathname: "/(app)/(organizer)/event-home", params: { eventGroupId: event.id } })
      }
      style={[styles.card, past && styles.cardPast]}
    >
      <View style={styles.cardHeader}>
        <Text style={styles.cardTitle} numberOfLines={2}>
          {event.name}
        </Text>
        <Text style={styles.cardType}>{EVENT_TYPE_LABELS[event.eventType] ?? event.eventType}</Text>
      </View>
      <Text style={styles.cardDate}>
        {event.primaryDate} · {whenLabel(event.primaryDate)}
      </Text>
      <View style={styles.cardFooter}>
        <Text style={styles.cardMeta}>{event.guestCountEstimate} guests</Text>
        <Text style={styles.cardMeta}>Budget {event.totalBudget.toLocaleString()}</Text>
      </View>
    </Pressable>
  );
}

export default function EventsScreen() {
  const { signOut } = useAuth();
  const data = useOrganizerData();

  // Pick up edits made on an event's page (name, budget, date) when coming back here.
  useFocusEffect(
    useCallback(() => {
      data.reloadEvents();
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [])
  );

  if (data.status !== "ready") return null;
  const events = [...data.eventGroups].sort((a, b) => a.primaryDate.localeCompare(b.primaryDate));

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>My events</Text>

      <Pressable
        onPress={() => router.push({ pathname: "/(app)/(organizer)/event-setup" })}
        style={styles.button}
      >
        <Text style={styles.buttonText}>+ Add event</Text>
      </Pressable>

      {events.length === 0 ? (
        <View style={styles.empty}>
          <Text style={styles.emptyTitle}>No events yet</Text>
          <Text style={styles.emptyText}>Create your first event to get a budget and a roadmap.</Text>
        </View>
      ) : (
        events.map((event) => <EventCard key={event.id} event={event} />)
      )}

      <Pressable onPress={signOut} style={[styles.button, styles.logoutButton]}>
        <Text style={styles.buttonText}>Log out</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { backgroundColor: "#fff", padding: 24, paddingTop: 64, gap: 12, flexGrow: 1 },
  title: { fontSize: 24, fontWeight: "700" },
  card: {
    borderWidth: 1,
    borderColor: "#ddd",
    borderRadius: 12,
    padding: 16,
    gap: 8,
    backgroundColor: "#fff",
    elevation: 2,
    shadowColor: "#000",
    shadowOpacity: 0.08,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 2 },
  },
  cardPast: { opacity: 0.6 },
  cardHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start", gap: 12 },
  cardTitle: { fontSize: 18, fontWeight: "600", flex: 1 },
  cardType: {
    fontSize: 12,
    fontWeight: "600",
    color: "#444",
    backgroundColor: "#f0f0f0",
    paddingVertical: 4,
    paddingHorizontal: 10,
    borderRadius: 12,
    overflow: "hidden",
  },
  cardDate: { fontSize: 14, color: "#666" },
  cardFooter: { flexDirection: "row", justifyContent: "space-between" },
  cardMeta: { fontSize: 14, color: "#111" },
  empty: { alignItems: "center", gap: 6, paddingVertical: 32 },
  emptyTitle: { fontSize: 18, fontWeight: "600" },
  emptyText: { fontSize: 14, color: "#666", textAlign: "center" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  buttonText: { color: "#fff", fontWeight: "600" },
  logoutButton: { marginTop: 24 },
});
