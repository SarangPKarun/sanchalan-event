import { Stack } from "expo-router";
import { useAuth } from "../../lib/auth-context";

export default function AppLayout() {
  const { role } = useAuth();

  return (
    <Stack>
      <Stack.Protected guard={role === "vendor"}>
        <Stack.Screen name="(vendor)" />
      </Stack.Protected>

      <Stack.Protected guard={role === "organizer"}>
        <Stack.Screen name="(organizer)" />
      </Stack.Protected>
    </Stack>
  );
}
