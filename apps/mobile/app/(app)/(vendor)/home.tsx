import { View, Text, Pressable, ScrollView, StyleSheet } from "react-native";
import { router } from "expo-router";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
import { useAuth } from "../../../lib/auth-context";
import { useVendorData } from "../../../lib/vendor-context";

export default function VendorHome() {
  const data = useVendorData();
  const { signOut } = useAuth();
  if (data.status !== "ready") return null;
  const { vendor } = data;

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.badge}>Published</Text>
      <Text style={styles.title}>{vendor.businessName}</Text>
      <Text style={styles.muted}>
        {vendor.vendorVendorCategories
          .map((c) => vendorCategoryLabel(c.vendorCategory.categoryKey))
          .join(", ")}{" "}
        · {vendor.priceTier} · {vendor.serviceArea}
      </Text>
      {vendor.description && <Text style={styles.body}>{vendor.description}</Text>}

      <Text style={styles.section}>Past work</Text>
      {vendor.portfolioItems.map((item) => (
        <View key={item.id} style={styles.pastWork}>
          <Text style={styles.pastWorkTitle}>{item.title}</Text>
          {item.caption && <Text style={styles.muted}>{item.caption}</Text>}
        </View>
      ))}

      <Text style={styles.hint}>
        Changing your business name, categories, price tier, service area, about text or past work
        sends your profile back for review.
      </Text>
      <Pressable onPress={() => router.push("/(app)/(vendor)/profile")} style={styles.button}>
        <Text style={styles.buttonText}>Edit profile</Text>
      </Pressable>
      <Pressable onPress={signOut}>
        <Text style={styles.link}>Log out</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { backgroundColor: "#fff", padding: 24, gap: 12, flexGrow: 1 },
  badge: { alignSelf: "flex-start", backgroundColor: "#e6f4ea", color: "#1e7a3c", paddingVertical: 4, paddingHorizontal: 10, borderRadius: 12, fontWeight: "600", overflow: "hidden" },
  title: { fontSize: 22, fontWeight: "600" },
  muted: { color: "#666", textTransform: "capitalize" },
  body: { fontSize: 15, color: "#333", lineHeight: 22 },
  section: { fontSize: 16, fontWeight: "600", marginTop: 12 },
  pastWork: { paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: "#eee", gap: 2 },
  pastWorkTitle: { fontSize: 15, fontWeight: "600" },
  hint: { color: "#666", fontSize: 13, marginTop: 12 },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  buttonText: { color: "#fff", fontWeight: "600" },
  link: { color: "#666", textAlign: "center", padding: 8 },
});
