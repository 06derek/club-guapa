import { z } from "zod";

/** La Ciudad de México usa UTC-6 todo el año (sin horario de verano desde 2022). */
export const MX_OFFSET = "-06:00";

/** Convierte "YYYY-MM-DDTHH:mm" (hora de CDMX) a ISO UTC. */
export function mexicoLocalToIso(local: string): string {
  return new Date(`${local}:00${MX_OFFSET}`).toISOString();
}

export function formatDateTimeMx(iso: string): string {
  return new Date(iso).toLocaleString("es-MX", {
    timeZone: "America/Mexico_City",
    weekday: "long",
    day: "numeric",
    month: "long",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatTimeMx(iso: string): string {
  return new Date(iso).toLocaleTimeString("es-MX", { timeZone: "America/Mexico_City", hour: "2-digit", minute: "2-digit" });
}

export function dayKeyMx(iso: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Mexico_City", year: "numeric", month: "2-digit", day: "2-digit" }).format(
    new Date(iso),
  );
}

export function formatDuration(minutes: number | null): string {
  if (!minutes) return "—";
  if (minutes >= 1440) {
    const d = Math.round(minutes / 1440);
    return `${d} día${d === 1 ? "" : "s"}`;
  }
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return h ? `${h} h${m ? ` ${m} min` : ""}` : `${m} min`;
}

export const calendarEventSchema = z.object({
  title: z.string().trim().min(3, "Nombre: mínimo 3 caracteres").max(120, "Nombre: máximo 120 caracteres"),
  platform: z.string().trim().min(2, "Plataforma: mínimo 2 caracteres").max(60, "Plataforma: máximo 60 caracteres"),
  startsAt: z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/, "Indica fecha y hora"),
  duration: z
    .string()
    .trim()
    .refine((v) => v === "" || (/^\d+$/.test(v) && Number(v) >= 1 && Number(v) <= 20160), "Duración: de 1 a 20160 minutos")
    .transform((v) => (v === "" ? null : Number(v))),
  url: z
    .string()
    .trim()
    .refine((v) => v === "" || /^https?:\/\/\S+$/i.test(v), "Usa un enlace que empiece con http:// o https://")
    .transform((v) => (v === "" ? null : v)),
  description: z
    .string()
    .trim()
    .max(500, "Descripción: máximo 500 caracteres")
    .transform((v) => (v === "" ? null : v)),
});
export type CalendarFormIn = z.input<typeof calendarEventSchema>;
export type CalendarFormOut = z.output<typeof calendarEventSchema>;
