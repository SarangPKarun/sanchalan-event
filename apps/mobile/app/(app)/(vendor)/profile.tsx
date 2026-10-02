import { useMemo, useState } from "react";
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  ActivityIndicator,
  ScrollView,
  TextInput,
  Alert,
  Platform,
} from "react-native";
import { router } from "expo-router";
import {
  VENDOR_DESCRIPTION_MAX,
  VENDOR_DESCRIPTION_MIN,
  VENDOR_MAX_CATEGORIES,
  VENDOR_MAX_PAST_WORK,
  VENDOR_PRICE_TIER_LABELS,
  VENDOR_REVIEW_TRIGGER_FIELDS,
  vendorCategoryLabel,
} from "@sanchalan/shared-types";
import type {
  ListVendorCategoriesResponse,
  PastWorkBody,
  UpdateVendorProfileBody,
  UpdateVendorProfileResponse,
  VendorMeResponse,
  VendorPortfolioItem,
  VendorPriceTier,
  VendorRequiredField,
} from "@sanchalan/shared-types";
import { useEffect } from "react";
import { api } from "../../../lib/api";
import { useAuth } from "../../../lib/auth-context";
import { PastWorkModal } from "../../../lib/PastWorkModal";
import { apiErrorMessage, useVendorData } from "../../../lib/vendor-context";

const PRICE_TIERS = Object.entries(VENDOR_PRICE_TIER_LABELS) as [VendorPriceTier, string][];

const MISSING_LABELS: Record<VendorRequiredField, string> = {
  businessName: "Business name",
  contactPersonName: "Contact person",
  priceTier: "Price tier",
  serviceArea: "Service area",
  description: `About (at least ${VENDOR_DESCRIPTION_MIN} characters)`,
  categories: "At least one category",
  pastWork: "At least one past-work entry",
};

const REVERIFY_NOTICE =
  "This change sends your profile back for review, and it will be hidden from families until it is approved again.";

function confirm(message: string): Promise<boolean> {
  if (Platform.OS === "web") return Promise.resolve(window.confirm(message));
  return new Promise((resolve) => {
    Alert.alert("Send back for review?", message, [
      { text: "Cancel", style: "cancel", onPress: () => resolve(false) },
      { text: "Continue", onPress: () => resolve(true) },
    ]);
  });
}

function parseIntOrNull(text: string): number | null {
  const digits = text.replace(/[^\d]/g, "");
  return digits ? parseInt(digits, 10) : null;
}

function emptyToNull(text: string): string | null {
  return text.trim() || null;
}

export default function VendorProfileScreen() {
  const data = useVendorData();
  const { signOut } = useAuth();
  if (data.status !== "ready") return null;
  return <ProfileForm vendor={data.vendor} apply={data.apply} signOut={signOut} />;
}

function ProfileForm({
  vendor,
  apply,
  signOut,
}: {
  vendor: VendorMeResponse;
  apply: (v: VendorMeResponse) => void;
  signOut: () => Promise<void>;
}) {
  const published = vendor.status === "published";

  const [businessName, setBusinessName] = useState(vendor.businessName ?? "");
  const [contactPersonName, setContactPersonName] = useState(vendor.contactPersonName ?? "");
  const [email, setEmail] = useState(vendor.email ?? "");
  const [priceTier, setPriceTier] = useState<VendorPriceTier | null>(vendor.priceTier);
  const [serviceArea, setServiceArea] = useState(vendor.serviceArea ?? "");
  const [description, setDescription] = useState(vendor.description ?? "");
  const [years, setYears] = useState(vendor.yearsOfExperience?.toString() ?? "");
  const [startingPrice, setStartingPrice] = useState(vendor.startingPrice?.toString() ?? "");
  const [instagramUrl, setInstagramUrl] = useState(vendor.instagramUrl ?? "");
  const [websiteUrl, setWebsiteUrl] = useState(vendor.websiteUrl ?? "");
  const [categoryKeys, setCategoryKeys] = useState<string[]>(
    vendor.vendorVendorCategories.map((c) => c.vendorCategory.categoryKey)
  );
  const [allCategories, setAllCategories] = useState<string[] | null>(null);
  const [categoriesError, setCategoriesError] = useState(false);

  const [busy, setBusy] = useState<null | "save" | "submit">(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const [modalOpen, setModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<VendorPortfolioItem | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const { data } = await api.get<ListVendorCategoriesResponse>("/vendor-categories");
        setAllCategories(data.categories.map((c) => c.categoryKey));
      } catch {
        setCategoriesError(true);
      }
    })();
  }, []);

  // Only the fields that differ from the server copy are sent.
  const profileChanges = useMemo(() => {
    const next: UpdateVendorProfileBody = {};
    if (businessName.trim() !== (vendor.businessName ?? "") && businessName.trim())
      next.businessName = businessName.trim();
    if (contactPersonName.trim() !== (vendor.contactPersonName ?? "") && contactPersonName.trim())
      next.contactPersonName = contactPersonName.trim();
    if (emptyToNull(email) !== vendor.email) next.email = emptyToNull(email);
    if (priceTier && priceTier !== vendor.priceTier) next.priceTier = priceTier;
    if (serviceArea.trim() !== (vendor.serviceArea ?? "") && serviceArea.trim())
      next.serviceArea = serviceArea.trim();
    if (description.trim() !== (vendor.description ?? "") && description.trim())
      next.description = description.trim();
    if (parseIntOrNull(years) !== vendor.yearsOfExperience) next.yearsOfExperience = parseIntOrNull(years);
    if (parseIntOrNull(startingPrice) !== vendor.startingPrice)
      next.startingPrice = parseIntOrNull(startingPrice);
    if (emptyToNull(instagramUrl) !== vendor.instagramUrl) next.instagramUrl = emptyToNull(instagramUrl);
    if (emptyToNull(websiteUrl) !== vendor.websiteUrl) next.websiteUrl = emptyToNull(websiteUrl);
    return next;
  }, [businessName, contactPersonName, email, priceTier, serviceArea, description, years, startingPrice, instagramUrl, websiteUrl, vendor]);

  const savedCategoryKeys = vendor.vendorVendorCategories.map((c) => c.vendorCategory.categoryKey);
  const categoriesChanged =
    categoryKeys.length !== savedCategoryKeys.length ||
    categoryKeys.some((k) => !savedCategoryKeys.includes(k));

  const hasChanges = Object.keys(profileChanges).length > 0 || categoriesChanged;
  const triggersReview =
    published &&
    (categoriesChanged || VENDOR_REVIEW_TRIGGER_FIELDS.some((f) => profileChanges[f] !== undefined));

  function toggleCategory(key: string) {
    setCategoryKeys((prev) => {
      if (prev.includes(key)) return prev.filter((k) => k !== key);
      if (prev.length >= VENDOR_MAX_CATEGORIES) return prev;
      return [...prev, key];
    });
  }

  /** Pushes pending edits to the server. Returns the latest vendor, or null on failure (error is set). */
  async function persist(): Promise<VendorMeResponse | null> {
    let latest = vendor;
    try {
      if (Object.keys(profileChanges).length > 0) {
        const { data } = await api.patch<UpdateVendorProfileResponse>("/vendor/me", profileChanges);
        latest = data.vendor;
        apply(latest);
        if (data.reverificationTriggered) return latest;
      }
      if (categoriesChanged) {
        const { data } = await api.put<UpdateVendorProfileResponse>("/vendor/me/categories", {
          categoryKeys,
        });
        latest = data.vendor;
        apply(latest);
      }
      return latest;
    } catch (err) {
      setError(apiErrorMessage(err, "Could not save your changes."));
      return null;
    }
  }

  async function handleSave() {
    setError(null);
    setNotice(null);
    if (triggersReview && !(await confirm(REVERIFY_NOTICE))) return;
    setBusy("save");
    const result = await persist();
    setBusy(null);
    if (result && !published) setNotice("Draft saved.");
    // A published vendor whose edit triggered re-review is moved to the "under review" screen by the layout.
    else if (result && published) router.back();
  }

  async function handleSubmit() {
    setError(null);
    setNotice(null);
    setBusy("submit");
    try {
      if (hasChanges && !(await persist())) return;
      const { data } = await api.post<VendorMeResponse>("/vendor/me/submit");
      apply(data);
    } catch (err) {
      const details = (err as { response?: { data?: { details?: { missing?: VendorRequiredField[] } } } })
        ?.response?.data?.details;
      if (details?.missing?.length) {
        setError(`Still needed: ${details.missing.map((m) => MISSING_LABELS[m]).join(", ")}.`);
      } else {
        setError(apiErrorMessage(err, "Could not submit your profile."));
      }
    } finally {
      setBusy(null);
    }
  }

  async function runPastWork(
    call: () => Promise<{ data: UpdateVendorProfileResponse }>,
    willTriggerReview: boolean
  ): Promise<string | null> {
    if (willTriggerReview && !(await confirm(REVERIFY_NOTICE))) return "Cancelled.";
    try {
      const { data } = await call();
      apply(data.vendor);
      setModalOpen(false);
      return null;
    } catch (err) {
      return apiErrorMessage(err, "Could not save this entry.");
    }
  }

  const savePastWork = (body: PastWorkBody) =>
    runPastWork(
      () =>
        editingItem
          ? api.patch<UpdateVendorProfileResponse>(`/vendor/me/past-work/${editingItem.id}`, body)
          : api.post<UpdateVendorProfileResponse>("/vendor/me/past-work", body),
      published
    );

  const deletePastWork = () =>
    runPastWork(() => api.delete<UpdateVendorProfileResponse>(`/vendor/me/past-work/${editingItem!.id}`), published);

  const missing = vendor.completeness.missing;

  return (
    <ScrollView contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
      <Text style={styles.title}>{published ? "Edit profile" : "Set up your business profile"}</Text>

      {vendor.status === "rejected" && (
        <View style={styles.rejected}>
          <Text style={styles.rejectedTitle}>Changes requested</Text>
          <Text style={styles.rejectedBody}>{vendor.rejectionReason ?? "Please review your profile."}</Text>
        </View>
      )}
      {!published && (
        <Text style={styles.hint}>
          Families browse vendors in Sanchalan once an admin approves your profile. Fill in everything
          below, then submit for review.
        </Text>
      )}

      <Text style={styles.section}>Business</Text>
      <Text style={styles.label}>Business name</Text>
      <TextInput value={businessName} onChangeText={setBusinessName} style={styles.input} maxLength={120} />
      <Text style={styles.label}>Contact person</Text>
      <TextInput value={contactPersonName} onChangeText={setContactPersonName} style={styles.input} maxLength={120} />
      <Text style={styles.label}>Email (optional)</Text>
      <TextInput value={email} onChangeText={setEmail} style={styles.input} autoCapitalize="none" keyboardType="email-address" />
      <Text style={styles.label}>Service area (city / region)</Text>
      <TextInput value={serviceArea} onChangeText={setServiceArea} style={styles.input} maxLength={200} placeholder="Pune, Mumbai" />

      <Text style={styles.section}>Categories (up to {VENDOR_MAX_CATEGORIES})</Text>
      {categoriesError && <Text style={styles.error}>Could not load categories.</Text>}
      {!allCategories && !categoriesError && <ActivityIndicator />}
      <View style={styles.chipRow}>
        {allCategories?.map((key) => (
          <Pressable
            key={key}
            onPress={() => toggleCategory(key)}
            style={[styles.chip, categoryKeys.includes(key) && styles.chipActive]}
          >
            <Text style={categoryKeys.includes(key) ? styles.chipTextActive : styles.chipText}>
              {vendorCategoryLabel(key)}
            </Text>
          </Pressable>
        ))}
      </View>

      <Text style={styles.section}>Pricing</Text>
      <View style={styles.chipRow}>
        {PRICE_TIERS.map(([value, label]) => (
          <Pressable
            key={value}
            onPress={() => setPriceTier(value)}
            style={[styles.chip, priceTier === value && styles.chipActive]}
          >
            <Text style={priceTier === value ? styles.chipTextActive : styles.chipText}>{label}</Text>
          </Pressable>
        ))}
      </View>
      <Text style={styles.label}>Starting price in ₹ (optional)</Text>
      <TextInput value={startingPrice} onChangeText={setStartingPrice} style={styles.input} keyboardType="number-pad" />

      <Text style={styles.section}>About</Text>
      <Text style={styles.label}>
        Tell families about your work ({description.trim().length}/{VENDOR_DESCRIPTION_MAX}, min {VENDOR_DESCRIPTION_MIN})
      </Text>
      <TextInput
        value={description}
        onChangeText={setDescription}
        style={[styles.input, styles.multiline]}
        multiline
        maxLength={VENDOR_DESCRIPTION_MAX}
      />
      <Text style={styles.label}>Years of experience (optional)</Text>
      <TextInput value={years} onChangeText={setYears} style={styles.input} keyboardType="number-pad" maxLength={2} />
      <Text style={styles.label}>Instagram link (optional)</Text>
      <TextInput value={instagramUrl} onChangeText={setInstagramUrl} style={styles.input} autoCapitalize="none" keyboardType="url" placeholder="https://instagram.com/..." />
      <Text style={styles.label}>Website (optional)</Text>
      <TextInput value={websiteUrl} onChangeText={setWebsiteUrl} style={styles.input} autoCapitalize="none" keyboardType="url" placeholder="https://..." />

      <Text style={styles.section}>Past work</Text>
      {vendor.portfolioItems.map((item) => (
        <Pressable
          key={item.id}
          style={styles.pastWork}
          onPress={() => {
            setEditingItem(item);
            setModalOpen(true);
          }}
        >
          <Text style={styles.pastWorkTitle}>{item.title}</Text>
          {item.caption && <Text style={styles.muted}>{item.caption}</Text>}
        </Pressable>
      ))}
      {vendor.portfolioItems.length < VENDOR_MAX_PAST_WORK && (
        <Pressable
          style={styles.secondaryButton}
          onPress={() => {
            setEditingItem(null);
            setModalOpen(true);
          }}
        >
          <Text style={styles.secondaryButtonText}>+ Add past work</Text>
        </Pressable>
      )}
      <Text style={styles.hint}>
        Unsaved changes above are kept while you add past work, but past-work entries are saved immediately.
      </Text>

      {!published && missing.length > 0 && (
        <View style={styles.checklist}>
          <Text style={styles.checklistTitle}>Before you can submit</Text>
          {missing.map((m) => (
            <Text key={m} style={styles.muted}>• {MISSING_LABELS[m]}</Text>
          ))}
          <Text style={styles.hint}>This list updates after you save.</Text>
        </View>
      )}

      {error && <Text style={styles.error}>{error}</Text>}
      {notice && <Text style={styles.notice}>{notice}</Text>}

      <Pressable
        onPress={handleSave}
        disabled={busy !== null || !hasChanges}
        style={[published ? styles.button : styles.secondaryButton, (busy !== null || !hasChanges) && styles.buttonDisabled]}
      >
        {busy === "save" ? (
          <ActivityIndicator color={published ? "#fff" : "#111"} />
        ) : (
          <Text style={published ? styles.buttonText : styles.secondaryButtonText}>
            {published ? "Save changes" : "Save draft"}
          </Text>
        )}
      </Pressable>

      {!published && (
        <Pressable
          onPress={handleSubmit}
          disabled={busy !== null}
          style={[styles.button, busy !== null && styles.buttonDisabled]}
        >
          {busy === "submit" ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.buttonText}>
              {vendor.status === "rejected" ? "Resubmit for review" : "Submit for review"}
            </Text>
          )}
        </Pressable>
      )}

      {published ? (
        <Pressable onPress={() => router.back()}>
          <Text style={styles.link}>Back</Text>
        </Pressable>
      ) : (
        <Pressable onPress={signOut}>
          <Text style={styles.link}>Log out</Text>
        </Pressable>
      )}

      <PastWorkModal
        visible={modalOpen}
        item={editingItem}
        onClose={() => setModalOpen(false)}
        onSave={savePastWork}
        onDelete={editingItem ? deletePastWork : undefined}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { backgroundColor: "#fff", padding: 24, gap: 10, paddingBottom: 48 },
  title: { fontSize: 22, fontWeight: "600" },
  section: { fontSize: 16, fontWeight: "600", marginTop: 16 },
  label: { fontSize: 14, color: "#666" },
  hint: { color: "#666", fontSize: 13 },
  muted: { color: "#666" },
  input: { borderWidth: 1, borderColor: "#ccc", borderRadius: 8, padding: 12 },
  multiline: { minHeight: 110, textAlignVertical: "top" },
  chipRow: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { paddingVertical: 8, paddingHorizontal: 14, borderRadius: 20, borderWidth: 1, borderColor: "#ccc" },
  chipActive: { backgroundColor: "#111", borderColor: "#111" },
  chipText: { color: "#111" },
  chipTextActive: { color: "#fff" },
  pastWork: { borderWidth: 1, borderColor: "#eee", borderRadius: 8, padding: 12, gap: 2 },
  pastWorkTitle: { fontSize: 15, fontWeight: "600" },
  checklist: { backgroundColor: "#fff8e6", borderRadius: 8, padding: 12, gap: 4, marginTop: 8 },
  checklistTitle: { fontWeight: "600" },
  rejected: { backgroundColor: "#fdecea", borderRadius: 8, padding: 12, gap: 4 },
  rejectedTitle: { fontWeight: "600", color: "#c00" },
  rejectedBody: { color: "#333" },
  error: { color: "#c00" },
  notice: { color: "#1e7a3c" },
  button: { backgroundColor: "#111", borderRadius: 8, padding: 14, alignItems: "center", marginTop: 8 },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: "#fff", fontWeight: "600" },
  secondaryButton: { borderWidth: 1, borderColor: "#111", borderRadius: 8, padding: 14, alignItems: "center" },
  secondaryButtonText: { color: "#111", fontWeight: "600" },
  link: { color: "#666", textAlign: "center", padding: 8 },
});
