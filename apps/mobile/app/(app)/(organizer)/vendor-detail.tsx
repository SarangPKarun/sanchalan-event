import { useCallback, useEffect, useState } from "react";
import { View, Text, Pressable, StyleSheet, ActivityIndicator, ScrollView, Image, Linking } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { api } from "../../../lib/api";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
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
    const digits = (vendor.whatsappNumber ?? vendor.phoneNumber).replace(/\D/g, "");
    const message = `Hi, I found ${vendor.businessName ?? "your business"} on Sanchalan and would like more information.`;
    Linking.openURL(`https://wa.me/${digits}?text=${encodeURIComponent(message)}`);
  }

  function openLink(url: string) {
    Linking.openURL(url);
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

      {vendor.portfolioItems.some((item) => item.mediaUrl) && (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.gallery}>
          {vendor.portfolioItems.map((item) =>
            item.mediaUrl ? (
              <Image key={item.id} source={{ uri: item.mediaUrl }} style={styles.galleryImage} />
            ) : null
          )}
        </ScrollView>
      )}

      {vendor.description && <Text style={styles.description}>{vendor.description}</Text>}

      <View style={styles.detailRow}>
        <Text style={styles.detailLabel}>Contact person</Text>
        <Text style={styles.detailValue}>{vendor.contactPersonName ?? "—"}</Text>
      </View>
      <View style={styles.detailRow}>
        <Text style={styles.detailLabel}>Categories</Text>
        <Text style={styles.detailValue}>
          {vendor.vendorVendorCategories
            .map((c) => vendorCategoryLabel(c.vendorCategory.categoryKey))
            .join(", ") || "—"}
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

      {vendor.yearsOfExperience != null && (
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Experience</Text>
          <Text style={styles.detailValue}>{vendor.yearsOfExperience} years</Text>
        </View>
      )}
      {vendor.startingPrice != null && (
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Starting price</Text>
          <Text style={styles.detailValue}>₹{vendor.startingPrice.toLocaleString("en-IN")}</Text>
        </View>
      )}

      {vendor.portfolioItems.length > 0 && (
        <>
          <Text style={styles.sectionTitle}>Past work</Text>
          {vendor.portfolioItems.map((item) => (
            <View key={item.id} style={styles.pastWork}>
              <Text style={styles.pastWorkTitle}>{item.title}</Text>
              {item.caption && <Text style={styles.pastWorkCaption}>{item.caption}</Text>}
            </View>
          ))}
        </>
      )}

      {(vendor.instagramUrl || vendor.websiteUrl) && (
        <>
          <Text style={styles.sectionTitle}>Links</Text>
          {vendor.instagramUrl && (
            <Pressable onPress={() => openLink(vendor.instagramUrl!)}>
              <Text style={styles.link}>Instagram</Text>
            </Pressable>
          )}
          {vendor.websiteUrl && (
            <Pressable onPress={() => openLink(vendor.websiteUrl!)}>
              <Text style={styles.link}>Website</Text>
            </Pressable>
          )}
        </>
      )}

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
  description: { fontSize: 15, color: "#333", lineHeight: 22 },
  pastWork: { paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: "#eee", gap: 2 },
  pastWorkTitle: { fontSize: 15, fontWeight: "600" },
  pastWorkCaption: { fontSize: 14, color: "#666" },
  link: { color: "#0a58ca", fontSize: 15, paddingVertical: 4 },
  contactRow: { flexDirection: "row", gap: 12 },
  button: { flex: 1, backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  whatsappButton: { backgroundColor: "#25D366" },
  buttonText: { color: "#fff", fontWeight: "600" },
  error: { color: "#c00", textAlign: "center" },
});
