import { z } from "zod";

/** RF-030/RF-031: datos de un recurso. La base de datos aplica las mismas reglas. */
export const resourceInputSchema = z.object({
  title: z.string().trim().min(3, "Título: mínimo 3 caracteres").max(120, "Título: máximo 120 caracteres"),
  description: z
    .string()
    .trim()
    .min(3, "Descripción: mínimo 3 caracteres")
    .max(1000, "Descripción: máximo 1000 caracteres"),
  url: z
    .string()
    .trim()
    .max(500, "Enlace: máximo 500 caracteres")
    .regex(/^https?:\/\/\S+$/i, "Usa un enlace que empiece con http:// o https://"),
  categoryId: z
    .string()
    .refine((v) => v === "" || /^[0-9a-f-]{36}$/i.test(v), "Categoría inválida")
    .transform((v) => (v === "" ? null : v)),
  visibility: z.enum(["public", "members"], { message: "Elige la visibilidad" }),
});
export type ResourceFormIn = z.input<typeof resourceInputSchema>;
export type ResourceFormOut = z.output<typeof resourceInputSchema>;

export const VISIBILITY_LABEL = { public: "Público", members: "Solo miembros" } as const;

/** RF-028/RF-029: filtra por categoría y texto (título, descripción o categoría). */
export function filterResources<T extends { title: string; description: string; category_id: string | null; categoryName?: string | null }>(
  items: T[],
  opts: { q: string; categoryId: string },
): T[] {
  const q = opts.q.trim().toLowerCase();
  return items.filter((r) => {
    if (opts.categoryId && r.category_id !== opts.categoryId) return false;
    if (!q) return true;
    return (
      r.title.toLowerCase().includes(q) ||
      r.description.toLowerCase().includes(q) ||
      (r.categoryName ?? "").toLowerCase().includes(q)
    );
  });
}
