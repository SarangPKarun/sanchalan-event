import { useCallback, useEffect, useMemo, useState } from "react";
import { View, Text, Pressable, StyleSheet, ActivityIndicator, ScrollView, Image } from "react-native";
import { router } from "expo-router";
import { api } from "../../../lib/api";
import { useOrganizerData } from "../../../lib/organizer-context";
import type { EventGroup, ListVendorsResponse, VendorPriceTier, VendorWithPortfolio } from "@sanchalan/shared-types";

const PRICE_TIERS: { value: VendorPriceTier; label: string }[] = [
  { value: "essential", label: "Essential" },
  { value: "standard", label: "Standard" },
  { value: "premium", label: "Premium" },
  { value: "luxury", label: "Luxury" },
];

function coverPhotoUrl(vendor: VendorWithPortfolio): string | null {
  return vendor.portfolioItems[0]?.mediaUrl ?? null;
}

export default function VendorsScreen() {
  const { eventGroupId } = useOrganizerData() as { eventGroupId: string };

  const [priceTier, setPriceTier] = useState<VendorPriceTier | null>(null);
  const [category, setCategory] = useState<string | null>(null);
  const [vendors, setVendors] = useState<VendorWithPortfolio[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // The organizer's own budget tier is only a *default* for the price-tier
  // filter — unlike event-home.tsx's primary data load, a failure to fetch
  // it should not block this screen, it should just leave the filter at
  // "all tiers".
  useEffect(() => {
    (async () => {
      try {
        const { data } = await api.get<EventGroup>(`/event-groups/${eventGroupId}`);
        setPriceTier(data.budgetTier);
      } catch {
        // fall back to "all tiers" — no error state needed here
      }
    })();
  }, [eventGroupId]);

  const fetchVendors = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { data } = await api.get<ListVendorsResponse>("/vendors", {
        params: {
          ...(priceTier ? { priceTier } : {}),
          ...(category ? { category } : {}),
        },
      });
      setVendors(data.vendors);
    } catch {
      setError("Could not load vendors.");
    } finally {
      setLoading(false);
    }
  }, [priceTier, category]);

  useEffect(() => {
    fetchVendors();
  }, [fetchVendors]);

  // Category chips reflect what's actually available under the current
  // price-tier filter — a deliberate progressive-narrowing UX, not a fixed
  // list from a separate categories endpoint.
  const categories = useMemo(() => {
    const keys = new Set<string>();
    for (const vendor of vendors) {
      for (const link of vendor.vendorVendorCategories) {
        keys.add(link.vendorCategory.categoryKey);
      }
    }
    return Array.from(keys).sort();
  }, [vendors]);

  function openVendor(vendorId: string) {
    router.push({ pathname: "/(app)/(organizer)/vendor-detail", params: { vendorId } });
  }

  return (
    <View style={styles.screen}>
      <Text style={styles.title}>Vendors</Text>

      <View style={styles.chipRow}>
        <Pressable
          onPress={() => setPriceTier(null)}
          style={[styles.chip, priceTier === null && styles.chipActive]}
        >
          <Text style={priceTier === null ? styles.chipTextActive : styles.chipText}>All tiers</Text>
        </Pressable>
        {PRICE_TIERS.map((tier) => (
          <Pressable
            key={tier.value}
            onPress={() => setPriceTier(tier.value)}
            style={[styles.chip, priceTier === tier.value && styles.chipActive]}
          >
            <Text style={priceTier === tier.value ? styles.chipTextActive : styles.chipText}>
              {tier.label}
            </Text>
          </Pressable>
        ))}
      </View>

      {categories.length > 0 && (
        <View style={styles.chipRow}>
          <Pressable
            onPress={() => setCategory(null)}
            style={[styles.chip, category === null && styles.chipActive]}
          >
            <Text style={category === null ? styles.chipTextActive : styles.chipText}>All categories</Text>
          </Pressable>
          {categories.map((key) => (
            <Pressable
              key={key}
              onPress={() => setCategory(key)}
              style={[styles.chip, category === key && styles.chipActive]}
            >
              <Text style={category === key ? styles.chipTextActive : styles.chipText}>{key}</Text>
            </Pressable>
          ))}
        </View>
      )}

      {loading && (
        <View style={styles.center}>
          <ActivityIndicator />
        </View>
      )}
      {error && (
        <View style={styles.center}>
          <Text style={styles.error}>{error}</Text>
        </View>
      )}
      {!loading && !error && vendors.length === 0 && (
        <View style={styles.center}>
          <Text style={styles.muted}>No vendors match these filters.</Text>
        </View>
      )}

      <ScrollView contentContainerStyle={styles.list}>
        {vendors.map((vendor) => {
          const cover = coverPhotoUrl(vendor);
          return (
            <Pressable key={vendor.id} onPress={() => openVendor(vendor.id)} style={styles.card}>
              {cover ? (
                <Image source={{ uri: cover }} style={styles.cardImage} />
              ) : (
                <View style={[styles.cardImage, styles.cardImagePlaceholder]} />
              )}
              <View style={styles.cardInfo}>
                <Text style={styles.cardName}>{vendor.businessName ?? "Unnamed vendor"}</Text>
                <Text style={styles.cardMeta}>
                  {vendor.priceTier ?? "no tier"} · {vendor.serviceArea ?? "no area"}
                </Text>
              </View>
            </Pressable>
          );
        })}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: "#fff", padding: 24, paddingBottom: 0, gap: 12 },
  title: { fontSize: 22, fontWeight: "600" },
  center: { padding: 24, alignItems: "center" },
  muted: { color: "#666" },
  error: { color: "#c00" },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { paddingVertical: 8, paddingHorizontal: 14, borderRadius: 20, borderWidth: 1, borderColor: "#ccc" },
  chipActive: { backgroundColor: "#111", borderColor: "#111" },
  chipText: { color: "#111" },
  chipTextActive: { color: "#fff" },
  list: { gap: 12, paddingVertical: 12 },
  card: {
    flexDirection: "row",
    gap: 12,
    borderWidth: 1,
    borderColor: "#eee",
    borderRadius: 8,
    padding: 8,
    alignItems: "center",
  },
  cardImage: { width: 64, height: 64, borderRadius: 6 },
  cardImagePlaceholder: { backgroundColor: "#eee" },
  cardInfo: { flex: 1, gap: 2 },
  cardName: { fontSize: 16, fontWeight: "600" },
  cardMeta: { fontSize: 14, color: "#666", textTransform: "capitalize" },
});
