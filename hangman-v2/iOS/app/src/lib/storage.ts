import { Preferences } from "@capacitor/preferences";

const KEYS = {
  token: "nfg_session_token",
  userId: "nfg_user_id",
  displayName: "nfg_display_name",
  deviceId: "nfg_device_id",
} as const;

function randomDeviceId(): string {
  return crypto.randomUUID();
}

export async function getDeviceId(): Promise<string> {
  const { value } = await Preferences.get({ key: KEYS.deviceId });
  if (value) return value;
  const id = randomDeviceId();
  await Preferences.set({ key: KEYS.deviceId, value: id });
  return id;
}

export async function getSession(): Promise<{
  token: string | null;
  userId: string;
  displayName: string;
}> {
  const [token, userId, displayName] = await Promise.all([
    Preferences.get({ key: KEYS.token }),
    Preferences.get({ key: KEYS.userId }),
    Preferences.get({ key: KEYS.displayName }),
  ]);
  return {
    token: token.value,
    userId: userId.value || "",
    displayName: displayName.value || userId.value || "",
  };
}

export async function saveSession(
  token: string,
  userId: string,
  displayName: string
): Promise<void> {
  await Promise.all([
    Preferences.set({ key: KEYS.token, value: token }),
    Preferences.set({ key: KEYS.userId, value: userId }),
    Preferences.set({
      key: KEYS.displayName,
      value: displayName || userId,
    }),
  ]);
}

export async function clearSession(): Promise<void> {
  await Promise.all([
    Preferences.remove({ key: KEYS.token }),
    Preferences.remove({ key: KEYS.userId }),
    Preferences.remove({ key: KEYS.displayName }),
  ]);
}
