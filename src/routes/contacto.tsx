import { createFileRoute } from "@tanstack/react-router";
import { Mail, MapPin, ExternalLink } from "lucide-react";
import { PageHero, SampleNotice } from "@/components/site/section-heading";
import { useSuspenseQuery } from "@tanstack/react-query";
import { contactQuery, isSampleContact } from "@/lib/site-settings";

export const Route = createFileRoute("/contacto")({
  head: () => ({
    meta: [
      { title: "Contacto · GUAPA FES Acatlán" },
      { name: "description", content: "Medios de contacto y ubicación del grupo GUAPA en la FES Acatlán." },
      { property: "og:title", content: "Contacto · GUAPA FES Acatlán" },
      { property: "og:description", content: "Cómo contactar y encontrar a GUAPA en la FES Acatlán." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  loader: ({ context }) => context.queryClient.ensureQueryData(contactQuery),
  component: ContactoPage,
});

function ContactoPage() {
  const { data: contact } = useSuspenseQuery(contactQuery);
  return (
    <>
      <PageHero eyebrow="contacto" title="Hablemos">
        ¿Dudas sobre el grupo o quieres unirte? Estos son nuestros medios de contacto.
      </PageHero>
      <section className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
        {isSampleContact(contact) ? <SampleNotice /> : null}
        <div className="mt-8 grid gap-4 md:grid-cols-3">
          {contact.email ? (
            <a
              href={`mailto:${contact.email}`}
              className="card-interactive rounded-xl border border-border bg-card p-6 shadow-card"
            >
              <Mail className="size-5 text-gold" aria-hidden />
              <p className="mt-4 font-mono text-xs uppercase tracking-[0.18em] text-muted-foreground">Correo</p>
              <p className="mt-1 break-all font-semibold">{contact.email}</p>
            </a>
          ) : null}
          <div className="rounded-xl border border-border bg-card p-6 shadow-card">
            <MapPin className="size-5 text-gold" aria-hidden />
            <p className="mt-4 font-mono text-xs uppercase tracking-[0.18em] text-muted-foreground">Ubicación</p>
            <p className="mt-1 font-semibold">{contact.location || "Por confirmar"}</p>
          </div>
          <div className="rounded-xl border border-border bg-card p-6 shadow-card">
            <ExternalLink className="size-5 text-gold" aria-hidden />
            <p className="mt-4 font-mono text-xs uppercase tracking-[0.18em] text-muted-foreground">Redes</p>
            {contact.socials.length === 0 ? <p className="mt-1 text-sm text-muted-foreground">Próximamente</p> : null}
            <ul className="mt-1 space-y-1">
              {contact.socials.map((s) => (
                <li key={s.key}>
                  <a href={s.href} target="_blank" rel="noreferrer" className="font-semibold hover:text-gold">
                    {s.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>
    </>
  );
}
