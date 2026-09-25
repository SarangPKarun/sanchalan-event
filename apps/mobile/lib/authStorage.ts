import * as SecureStore from "expo-secure-store";
import type { AuthTokens, Role } from "./types";

export const ACCESS_TOKEN_KEY = "sanchalan.accessToken";
export const REFRESH_TOKEN_KEY = "sanchalan.refreshToken";
export const ROLE_KEY = "sanchalan.role";

export const getAccessToken = () => SecureStore.getItemAsync(ACCESS_TOKEN_KEY);
export const getRefreshToken = () => SecureStore.getItemAsync(REFRESH_TOKEN_KEY);
export const getRole = () => SecureStore.getItemAsync(ROLE_KEY) as Promise<Role | null>;

export async function setTokens({ accessToken, refreshToken }: AuthTokens) {
  await Promise.all([
    SecureStore.setItemAsync(ACCESS_TOKEN_KEY, accessToken),
    SecureStore.setItemAsync(REFRESH_TOKEN_KEY, refreshToken),
  ]);
}

export const setRole = (role: Role) => SecureStore.setItemAsync(ROLE_KEY, role);

export async function clearTokens() {
  await Promise.all([
    SecureStore.deleteItemAsync(ACCESS_TOKEN_KEY),
    SecureStore.deleteItemAsync(REFRESH_TOKEN_KEY),
    SecureStore.deleteItemAsync(ROLE_KEY),
  ]);
}
