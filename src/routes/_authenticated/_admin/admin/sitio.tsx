import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useQueryClient, useSuspenseQuery } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { Loader2, Save, Share2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { FieldError } from "@/components/site/auth-shell";
import { FormAlert, FormCard } from "@/components/site/form-ui";
import { CONTACT_KEYS, contactSettingsQuery, contactSettingsSchema, type ContactSettings } from "@/lib/site-settings";

export const Route = createFileRoute("/_authenticated/_admin/admin/sitio")({
  head: () => ({ meta: [{ title: "Contacto y redes · Administración GUAPA" }, { name: "robots", content: "noindex" }] }),
  loader: ({ context }) => context.queryClient.ensureQueryData(contactSettingsQuery),
  component: SitioPage,
});

const fields: { key: keyof ContactSettings; label: string; placeholder: string; type?: string }[] = [
  { key: "contact_email", label: "Correo de contacto", placeholder: "guapa@acatlan.unam.mx", type: "email" },
  { key: "contact_location", label: "Ubicación", placeholder: "CEDETEC, FES Acatlán" },
  { key: "social_facebook", label: "Facebook", placeholder: "https://facebook.com/tu-pagina" },
  { key: "social_discord", label: "Discord (invitación)", placeholder: "https://discord.gg/…" },
];

function SitioPage() {
  const { data } = useSuspenseQuery(contactSettingsQuery);
  const qc = useQueryClient();
  const [formError, setFormError] = useState<string | null>(null);
  const { register, handleSubmit, formState, reset } = useForm<ContactSettings>({
    resolver: zodResolver(contactSettingsSchema),
    defaultValues: data,
  });

  async function onSubmit(v: ContactSettings) {
    setFormError(null);
    const results = await Promise.all(
      CONTACT_KEYS.map((key) => supabase.from("site_settings").update({ value: v[key] }).eq("key", key).select("key")),
    );
    const failed = results.find((r) => r.error || !r.data?.length);
    if (failed) {
      setFormError(failed.error?.code === "23514" ? "Algún dato no tiene el formato correcto." : "No se pudieron guardar los cambios.");
      return;
    }
    toast.success("Contacto actualizado");
    reset(v);
    qc.invalidateQueries({ queryKey: ["public", "contact"] });
    qc.invalidateQueries({ queryKey: ["admin", "contact-settings"] });
  }

  return (
    <div className="max-w-2xl">
      <h2 className="text-2xl font-bold">Contacto y redes sociales</h2>
      <p className="mt-1 text-muted-foreground">
        Estos datos aparecen en la página de Contacto, en la página de inicio y al pie de todas las páginas. Deja un campo
        vacío para ocultarlo.
      </p>
      <FormCard title="Datos de contacto" icon={Share2} className="mt-8">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
          {fields.map((f) => (
            <div key={f.key}>
              <Label htmlFor={f.key}>{f.label}</Label>
              <Input id={f.key} type={f.type ?? "text"} placeholder={f.placeholder} className="mt-1.5" {...register(f.key)} />
              <FieldError message={formState.errors[f.key]?.message} />
            </div>
          ))}
          {formError ? <FormAlert>{formError}</FormAlert> : null}
          <Button type="submit" variant="gold" disabled={formState.isSubmitting || !formState.isDirty}>
            {formState.isSubmitting ? <Loader2 className="animate-spin" /> : <Save />}
            Guardar cambios
          </Button>
        </form>
      </FormCard>
    </div>
  );
}
