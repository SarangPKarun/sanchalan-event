export const ACCESS_TOKEN_KEY = "sanchalan.admin.accessToken";
export const REFRESH_TOKEN_KEY = "sanchalan.admin.refreshToken";

export const getAccessToken = () => localStorage.getItem(ACCESS_TOKEN_KEY);
export const getRefreshToken = () => localStorage.getItem(REFRESH_TOKEN_KEY);

export function setTokens({
  accessToken,
  refreshToken,
}: {
  accessToken: string;
  refreshToken: string;
}): void {
  localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
  localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
}

export function clearTokens(): void {
  localStorage.removeItem(ACCESS_TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
}
