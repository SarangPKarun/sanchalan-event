import { Stack } from "expo-router";

export const unstable_settings = {
  initialRouteName: "phone",
};

export default function AuthLayout() {
  return <Stack screenOptions={{ headerShown: false }} />;
}
