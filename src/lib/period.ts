/** Periodos para Scoreboard, estadísticas e historial (RF-044, RF-045, RF-056, RF-080). */
export type PeriodPreset = "week" | "month" | "semester" | "year" | "all" | "custom";

export const PERIOD_PRESETS: { value: PeriodPreset; label: string }[] = [
  { value: "week", label: "7 días" },
  { value: "month", label: "Este mes" },
  { value: "semester", label: "Semestre" },
  { value: "year", label: "Este año" },
  { value: "all", label: "Todo" },
  { value: "custom", label: "Personalizado" },
];

/** Fecha más antigua considerada "todo el historial". */
export const ALL_TIME_FROM = "2000-01-01";

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Fecha de hoy (YYYY-MM-DD) en la Ciudad de México. */
export function todayInMexico(now: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Mexico_City",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

/** Verifica formato YYYY-MM-DD y que la fecha exista en el calendario (RF-059). */
export function isRealDate(value: string): boolean {
  if (!ISO_DATE.test(value)) return false;
  const [y = 0, m = 0, d = 0] = value.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}

function shift(iso: string, days: number): string {
  const [y = 0, m = 1, d = 1] = iso.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d + days));
  return date.toISOString().slice(0, 10);
}

/** Rango de fechas para un periodo predefinido, relativo a `today` (YYYY-MM-DD). */
export function presetRange(preset: Exclude<PeriodPreset, "custom">, today: string): { from: string; to: string } {
  const [y = 2000, m = 1] = today.split("-").map(Number);
  const mm = String(m).padStart(2, "0");
  switch (preset) {
    case "week":
      return { from: shift(today, -6), to: today };
    case "month":
      return { from: `${y}-${mm}-01`, to: today };
    case "semester": {
      // Semestres UNAM aproximados: agosto–enero y febrero–julio.
      if (m >= 8) return { from: `${y}-08-01`, to: today };
      if (m === 1) return { from: `${y - 1}-08-01`, to: today };
      return { from: `${y}-02-01`, to: today };
    }
    case "year":
      return { from: `${y}-01-01`, to: today };
    case "all":
      return { from: ALL_TIME_FROM, to: today };
  }
}

/** RF-045: la fecha inicial no puede ser posterior a la final. Devuelve un mensaje o null. */
export function periodError(from: string, to: string): string | null {
  if (!from || !to) return "Indica la fecha inicial y la final.";
  if (!isRealDate(from) || !isRealDate(to)) return "Usa fechas válidas.";
  if (from > to) return "La fecha inicial no puede ser posterior a la final.";
  return null;
}
