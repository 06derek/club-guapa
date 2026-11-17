import { useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2, MailCheck } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { AuthShell, FieldError } from "@/components/site/auth-shell";
import { authErrorMessage, forgotSchema, type ForgotInput } from "@/lib/auth-rules";

export const Route = createFileRoute("/recuperar")({
  head: () => ({
    meta: [
      { title: "Recuperar contraseña · GUAPA FES Acatlán" },
      { name: "description", content: "Recibe un enlace para crear una nueva contraseña de tu cuenta GUAPA." },
      { property: "og:title", content: "Recuperar contraseña · GUAPA" },
      { property: "og:description", content: "Recibe un enlace para crear una nueva contraseña de tu cuenta GUAPA." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ForgotPage,
});

function ForgotPage() {
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const { register, handleSubmit, formState } = useForm<ForgotInput>({ resolver: zodResolver(forgotSchema) });

  async function onSubmit(values: ForgotInput) {
    setFormError(null);
    const { error } = await supabase.auth.resetPasswordForEmail(values.email.trim(), {
      redirectTo: `${window.location.origin}/restablecer`,
    });
    if (error) {
      setFormError(authErrorMessage(error.message));
      return;
    }
    setSentTo(values.email.trim());
  }

  if (sentTo) {
    return (
      <AuthShell eyebrow="recuperar" title="Revisa tu correo">
        <div className="flex flex-col items-center text-center">
          <span className="grid size-12 place-items-center rounded-full bg-success/15 text-success">
            <MailCheck className="size-6" aria-hidden />
          </span>
          <p className="mt-4 text-sm text-muted-foreground">
            Si existe una cuenta con <span className="font-medium text-foreground">{sentTo}</span>, recibirás un
            enlace para crear una nueva contraseña.
          </p>
          <Button asChild variant="glass" className="mt-6">
            <Link to="/login" search={{ redirect: undefined }}>
              Volver a iniciar sesión
            </Link>
          </Button>
        </div>
      </AuthShell>
    );
  }

  return (
    <AuthShell
      eyebrow="recuperar"
      title="Recupera tu acceso"
      subtitle="Te enviaremos un enlace para crear una nueva contraseña."
      footer={
        <Link to="/login" search={{ redirect: undefined }} className="font-medium text-gold hover:underline">
          Volver a iniciar sesión
        </Link>
      }
    >
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        <div>
          <Label htmlFor="email">Correo</Label>
          <Input id="email" type="email" autoComplete="email" className="mt-1.5" {...register("email")} />
          <FieldError message={formState.errors.email?.message} />
        </div>
        {formError ? (
          <p role="alert" className="rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm text-destructive">
            {formError}
          </p>
        ) : null}
        <Button type="submit" variant="gold" size="lg" className="w-full" disabled={formState.isSubmitting}>
          {formState.isSubmitting ? <Loader2 className="animate-spin" /> : null}
          Enviar enlace
        </Button>
      </form>
    </AuthShell>
  );
}
