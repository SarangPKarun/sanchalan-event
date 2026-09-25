import { useCallback, useEffect, useState } from "react";
import { View, Text, Pressable, StyleSheet, ActivityIndicator, ScrollView, Image, Linking } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { api } from "../../../lib/api";
import type { VendorWithPortfolio } from "@sanchalan/shared-types";

export default function VendorDetailScreen() {
  const { vendorId } = useLocalSearchParams<{ vendorId: string }>();

  const [vendor, setVendor] = useState<VendorWithPortfolio | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const { data } = await api.get<VendorWithPortfolio>(`/vendors/${vendorId}`);
      setVendor(data);
    } catch {
      setError("Could not load this vendor.");
    }
  }, [vendorId]);

  useEffect(() => {
    load();
  }, [load]);

  function handleCall() {
    if (!vendor) return;
    Linking.openURL(`tel:${vendor.phoneNumber}`);
  }

  function handleWhatsApp() {
    if (!vendor) return;
    const digits = vendor.phoneNumber.replace(/\D/g, "");
    const message = `Hi, I found ${vendor.businessName ?? "your business"} on Sanchalan and would like more information.`;
    Linking.openURL(`https://wa.me/${digits}?text=${encodeURIComponent(message)}`);
  }

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.error}>{error}</Text>
      </View>
    );
  }

  if (!vendor) {
    return (
      <View style={styles.center}>
        <ActivityIndicator />
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{vendor.businessName ?? "Unnamed vendor"}</Text>

      {vendor.portfolioItems.length > 0 && (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.gallery}>
          {vendor.portfolioItems.map((item) => (
            <Image key={item.id} source={{ uri: item.mediaUrl }} style={styles.galleryImage} />
          ))}
        </ScrollView>
      )}

      <View style={styles.detailRow}>
        <Text style={styles.detailLabel}>Contact person</Text>
        <Text style={styles.detailValue}>{vendor.contactPersonName ?? "—"}</Text>
      </View>
      <View style={styles.detailRow}>
        <Text style={styles.detailLabel}>Categories</Text>
        <Text style={styles.detailValue}>
          {vendor.vendorVendorCategories.map((c) => c.vendorCategory.categoryKey).join(", ") || "—"}
        </Text>
      </View>
      <View style={styles.detailRow}>
        <Text style={styles.detailLabel}>Price tier</Text>
        <Text style={styles.detailValue}>{vendor.priceTier ?? "—"}</Text>
      </View>
      <View style={styles.detailRow}>
        <Text style={styles.detailLabel}>Service area</Text>
        <Text style={styles.detailValue}>{vendor.serviceArea ?? "—"}</Text>
      </View>

      <Text style={styles.sectionTitle}>Contact</Text>
      <View style={styles.contactRow}>
        <Pressable onPress={handleCall} style={styles.button}>
          <Text style={styles.buttonText}>Call</Text>
        </Pressable>
        <Pressable onPress={handleWhatsApp} style={[styles.button, styles.whatsappButton]}>
          <Text style={styles.buttonText}>WhatsApp</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { backgroundColor: "#fff", padding: 24, gap: 12 },
  center: { flex: 1, backgroundColor: "#fff", alignItems: "center", justifyContent: "center" },
  title: { fontSize: 22, fontWeight: "600" },
  gallery: { flexDirection: "row" },
  galleryImage: { width: 220, height: 160, borderRadius: 8, marginRight: 8 },
  sectionTitle: { fontSize: 16, fontWeight: "600", marginTop: 16 },
  detailRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: "#ccc",
  },
  detailLabel: { fontSize: 14, color: "#666" },
  detailValue: { fontSize: 14, fontWeight: "600", textTransform: "capitalize", flexShrink: 1, textAlign: "right" },
  contactRow: { flexDirection: "row", gap: 12 },
  button: { flex: 1, backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  whatsappButton: { backgroundColor: "#25D366" },
  buttonText: { color: "#fff", fontWeight: "600" },
  error: { color: "#c00", textAlign: "center" },
});
