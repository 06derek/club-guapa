/** Reglas y utilidades de Codeforces (RF-041 a RF-050). La base de datos aplica las mismas reglas. */
export const CF_HANDLE_RE = /^[A-Za-z0-9_.-]{3,24}$/;

export function isValidHandle(handle: string): boolean {
  return CF_HANDLE_RE.test(handle.trim());
}

export type SyncResult = "ok" | "error" | "pending" | "not_found" | "none";

export function syncMessage(result: SyncResult): { tone: "success" | "error" | "info"; text: string } {
  switch (result) {
    case "ok":
      return { tone: "success", text: "Datos de Codeforces actualizados." };
    case "not_found":
      return { tone: "error", text: "Ese usuario no existe en Codeforces. La cuenta no se vinculó." };
    case "pending":
      return { tone: "info", text: "Codeforces sigue respondiendo; los datos aparecerán en unos minutos." };
    case "none":
      return { tone: "error", text: "No tienes una cuenta de Codeforces vinculada." };
    default:
      return {
        tone: "error",
        text: "No se pudieron actualizar los datos de Codeforces. Se conservan los datos anteriores.",
      };
  }
}

export function codeforcesErrorMessage(error: unknown): string {
  const msg = ((error ?? {}) as { message?: string }).message ?? "";
  if (msg.includes("CF_HANDLE_TAKEN")) return "Ese usuario de Codeforces ya está vinculado a otra cuenta.";
  if (msg.includes("CF_HANDLE_INVALID")) return "Usuario de Codeforces inválido (3 a 24 letras, números, _ . -).";
  if (msg.includes("CF_NOT_LINKED")) return "Primero vincula tu cuenta de Codeforces.";
  if (msg.includes("CF_SYNC_TOO_SOON")) return "Espera un minuto antes de volver a actualizar.";
  if (msg.includes("USER_NOT_ELIGIBLE")) return "Tu cuenta está desactivada.";
  if (msg.includes("INVALID_PERIOD")) return "La fecha inicial no puede ser posterior a la final.";
  return "No se pudo completar la operación con Codeforces.";
}

/** Color por rating usando tokens del tema. */
export function ratingTone(rating: number | null | undefined): string {
  if (rating == null) return "text-muted-foreground";
  if (rating >= 2400) return "text-destructive";
  if (rating >= 2100) return "text-chart-5";
  if (rating >= 1900) return "text-gold";
  if (rating >= 1600) return "text-primary";
  if (rating >= 1400) return "text-chart-4";
  if (rating >= 1200) return "text-success";
  return "text-muted-foreground";
}

export function profileUrl(handle: string): string {
  return `https://codeforces.com/profile/${encodeURIComponent(handle)}`;
}

export function problemUrl(contestId: number | null, index: string): string | null {
  if (contestId == null) return null;
  const kind = contestId >= 100000 ? "gym" : "contest";
  return `https://codeforces.com/${kind}/${contestId}/problem/${encodeURIComponent(index)}`;
}

/** Consulta pública rápida para dar retroalimentación inmediata al vincular. */
export async function lookupHandle(
  handle: string,
): Promise<{ status: "found"; handle: string } | { status: "not_found" } | { status: "unavailable" }> {
  try {
    const res = await fetch(`https://codeforces.com/api/user.info?handles=${encodeURIComponent(handle.trim())}`);
    const json = (await res.json()) as { status?: string; comment?: string; result?: { handle: string }[] };
    if (json.status === "OK" && json.result?.[0]) return { status: "found", handle: json.result[0].handle };
    if (json.comment?.toLowerCase().includes("not found")) return { status: "not_found" };
    return { status: "unavailable" };
  } catch {
    return { status: "unavailable" };
  }
}
