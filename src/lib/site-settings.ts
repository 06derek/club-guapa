import { queryOptions } from "@tanstack/react-query";
import { z } from "zod";
import { supabase } from "@/integrations/supabase/client";
import { contact as sampleContact } from "@/content/site";

/** Datos de contacto editables por administradores (RF-005, RF-008). La base de datos aplica las mismas reglas. */
export const CONTACT_KEYS = ["contact_email", "contact_location", "social_facebook", "social_discord"] as const;
export type ContactKey = (typeof CONTACT_KEYS)[number];

export type ContactInfo = {
  email: string;
  location: string;
  socials: { key: "social_facebook" | "social_discord"; label: string; href: string }[];
};

const SOCIAL_LABEL = { social_facebook: "Facebook", social_discord: "Discord" } as const;

const optionalUrl = (label: string) =>
  z
    .string()
    .trim()
    .max(500, `${label}: máximo 500 caracteres`)
    .refine((v) => v === "" || /^https?:\/\/\S+$/i.test(v), `${label}: usa un enlace que empiece con http:// o https://`);

export const contactSettingsSchema = z.object({
  contact_email: z
    .string()
    .trim()
    .max(200, "Correo: máximo 200 caracteres")
    .refine((v) => v === "" || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v), "Correo inválido"),
  contact_location: z.string().trim().max(300, "Ubicación: máximo 300 caracteres"),
  social_facebook: optionalUrl("Facebook"),
  social_discord: optionalUrl("Discord"),
});
export type ContactSettings = z.infer<typeof contactSettingsSchema>;

/** Convierte las filas guardadas en la información que muestra el sitio. Las redes vacías no se muestran. */
export function toContactInfo(rows: { key: string; value: string }[]): ContactInfo {
  const get = (k: ContactKey) => rows.find((r) => r.key === k)?.value?.trim() ?? "";
  if (!rows.some((r) => (CONTACT_KEYS as readonly string[]).includes(r.key))) return fallbackContact();
  return {
    email: get("contact_email"),
    location: get("contact_location"),
    socials: (["social_facebook", "social_discord"] as const)
      .map((key) => ({ key, label: SOCIAL_LABEL[key], href: get(key) }))
      .filter((s) => s.href !== ""),
  };
}

function fallbackContact(): ContactInfo {
  return {
    email: sampleContact.email,
    location: sampleContact.location,
    socials: (["social_facebook", "social_discord"] as const).map((key) => ({
      key,
      label: SOCIAL_LABEL[key],
      href: sampleContact.socials.find((s) => s.label === SOCIAL_LABEL[key])?.href ?? "",
    })),
  };
}

export function isSampleContact(c: ContactInfo): boolean {
  return c.email.endsWith("@ejemplo.mx");
}

export const contactQuery = queryOptions({
  queryKey: ["public", "contact"],
  queryFn: async (): Promise<ContactInfo> => {
    const { data, error } = await supabase.from("site_settings").select("key, value").in("key", [...CONTACT_KEYS]);
    if (error) throw error;
    return toContactInfo(data);
  },
  staleTime: 60_000,
});

export const contactSettingsQuery = queryOptions({
  queryKey: ["admin", "contact-settings"],
  queryFn: async (): Promise<ContactSettings> => {
    const { data, error } = await supabase.from("site_settings").select("key, value").in("key", [...CONTACT_KEYS]);
    if (error) throw error;
    const get = (k: ContactKey) => data.find((r) => r.key === k)?.value ?? "";
    return {
      contact_email: get("contact_email"),
      contact_location: get("contact_location"),
      social_facebook: get("social_facebook"),
      social_discord: get("social_discord"),
    };
  },
});
