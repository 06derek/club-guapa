import { useEffect, useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Loader2 } from "lucide-react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { AuthShell, FieldError } from "@/components/site/auth-shell";
import { authErrorMessage, resetSchema, type ResetInput } from "@/lib/auth-rules";

export const Route = createFileRoute("/restablecer")({
  head: () => ({
    meta: [
      { title: "Nueva contraseña · GUAPA FES Acatlán" },
      { name: "description", content: "Crea una nueva contraseña para tu cuenta GUAPA." },
      { property: "og:title", content: "Nueva contraseña · GUAPA" },
      { property: "og:description", content: "Crea una nueva contraseña para tu cuenta GUAPA." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ResetPage,
});

function ResetPage() {
  const navigate = useNavigate();
  const [ready, setReady] = useState<boolean | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const { register, handleSubmit, formState } = useForm<ResetInput>({ resolver: zodResolver(resetSchema) });

  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === "PASSWORD_RECOVERY" || session) setReady(true);
    });
    supabase.auth.getSession().then(({ data: { session } }) => {
      setReady((prev) => prev ?? !!session);
    });
    return () => data.subscription.unsubscribe();
  }, []);

  async function onSubmit(values: ResetInput) {
    setFormError(null);
    const { error } = await supabase.auth.updateUser({ password: values.password });
    if (error) {
      setFormError(authErrorMessage(error.message));
      return;
    }
    toast.success("Contraseña actualizada");
    navigate({ to: "/panel", replace: true });
  }

  if (ready === false) {
    return (
      <AuthShell eyebrow="recuperar" title="Enlace no válido">
        <p className="text-sm text-muted-foreground">
          El enlace expiró o ya se usó. Solicita uno nuevo para crear tu contraseña.
        </p>
        <Button asChild variant="gold" className="mt-6 w-full">
          <Link to="/recuperar">Solicitar nuevo enlace</Link>
        </Button>
      </AuthShell>
    );
  }

  return (
    <AuthShell eyebrow="recuperar" title="Crea tu nueva contraseña">
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        <div>
          <Label htmlFor="password">Nueva contraseña</Label>
          <Input id="password" type="password" autoComplete="new-password" className="mt-1.5" {...register("password")} />
          <FieldError message={formState.errors.password?.message} />
        </div>
        <div>
          <Label htmlFor="confirm">Confirma la contraseña</Label>
          <Input id="confirm" type="password" autoComplete="new-password" className="mt-1.5" {...register("confirm")} />
          <FieldError message={formState.errors.confirm?.message} />
        </div>
        {formError ? (
          <p role="alert" className="rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm text-destructive">
            {formError}
          </p>
        ) : null}
        <Button type="submit" variant="gold" size="lg" className="w-full" disabled={formState.isSubmitting || !ready}>
          {formState.isSubmitting || ready === null ? <Loader2 className="animate-spin" /> : null}
          Guardar contraseña
        </Button>
      </form>
    </AuthShell>
  );
}
