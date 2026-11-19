// Safari throws on every localStorage call when all site data is blocked.
export function readPreference(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function writePreference(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {}
}
