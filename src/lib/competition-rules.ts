import { z } from "zod";
import { isRealDate, todayInMexico } from "@/lib/period";

/** RF-051 a RF-060: registro de competencias externas. La base de datos aplica las mismas reglas. */
const optionalInt = (label: string, min: number) =>
  z
    .string()
    .trim()
    .refine((v) => v === "" || (/^\d+$/.test(v) && Number(v) >= min), `${label}: número entero mayor o igual a ${min}`)
    .transform((v) => (v === "" ? null : Number(v)));

export const competitionInputSchema = z
  .object({
    platformId: z.string().uuid("Elige una plataforma"),
    contestName: z.string().trim().min(3, "Nombre: mínimo 3 caracteres").max(120, "Nombre: máximo 120 caracteres"),
    contestDate: z
      .string()
      .min(1, "La fecha es obligatoria")
      .refine(isRealDate, "Fecha inválida")
      .refine((v) => v >= "2000-01-01", "La fecha debe ser del año 2000 en adelante")
      .refine((v) => v <= todayInMexico(), "La fecha no puede ser futura"),
    solved: z
      .string()
      .trim()
      .min(1, "Indica cuántos problemas resolviste")
      .refine((v) => /^\d+$/.test(v) && Number(v) <= 100, "Problemas resueltos: entero entre 0 y 100")
      .transform(Number),
    place: optionalInt("Lugar", 1),
    participants: optionalInt("Participantes", 1),
    score: z
      .string()
      .trim()
      .refine((v) => v === "" || (/^\d+(\.\d{1,2})?$/.test(v) && Number(v) < 1e8), "Puntaje: número positivo (máx. 2 decimales)")
      .transform((v) => (v === "" ? null : Number(v))),
    notes: z
      .string()
      .trim()
      .max(500, "Notas: máximo 500 caracteres")
      .transform((v) => (v === "" ? null : v)),
  })
  .refine((v) => v.place == null || v.participants == null || v.place <= v.participants, {
    message: "El lugar no puede ser mayor que el número de participantes",
    path: ["place"],
  });

export type CompetitionFormIn = z.input<typeof competitionInputSchema>;
export type CompetitionFormOut = z.output<typeof competitionInputSchema>;

export function competitionErrorMessage(error: unknown): string {
  const e = (error ?? {}) as { message?: string; code?: string };
  const msg = e.message ?? "";
  if (msg.includes("DATE_IN_FUTURE")) return "La fecha no puede ser futura.";
  if (msg.includes("DATE_TOO_OLD")) return "La fecha debe ser del año 2000 en adelante.";
  if (msg.includes("place_le_participants")) return "El lugar no puede ser mayor que el número de participantes.";
  if (e.code === "42501") return "No tienes permiso para hacer esto.";
  if (e.code === "23503") return "La plataforma seleccionada ya no existe.";
  if (e.code === "23514") return "Algún dato no cumple el formato requerido.";
  return "No se pudo guardar la competencia.";
}

export function formatResult(r: { solved: number; place: number | null; participants: number | null; score: number | null }): string {
  const parts = [`${r.solved} resuelto${r.solved === 1 ? "" : "s"}`];
  if (r.place != null) parts.push(r.participants != null ? `lugar ${r.place}/${r.participants}` : `lugar ${r.place}`);
  if (r.score != null) parts.push(`${r.score} pts`);
  return parts.join(" · ");
}
