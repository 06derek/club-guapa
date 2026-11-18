import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { club } from "@/content/site";
import { contactQuery } from "@/lib/site-settings";
import { navLinks } from "./nav-links";

export function SiteFooter() {
  const { data: contact } = useQuery(contactQuery);
  return (
    <footer className="mt-24 border-t border-border bg-surface">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:px-6 md:grid-cols-[1.4fr_1fr_1fr]">
        <div>
          <p className="font-display text-lg font-bold">{club.name}</p>
          <p className="mt-2 max-w-sm text-sm text-muted-foreground">{club.fullName}</p>
          <p className="mt-4 font-mono text-xs text-muted-foreground">
            {club.parent} · {club.institution}
          </p>
        </div>
        <div>
          <p className="font-mono text-xs uppercase tracking-[0.18em] text-muted-foreground">Secciones</p>
          <ul className="mt-3 space-y-2 text-sm">
            {navLinks.map((l) => (
              <li key={l.to}>
                <Link to={l.to} className="text-foreground/80 transition-colors hover:text-gold">
                  {l.label}
                </Link>
              </li>
            ))}
          </ul>
        </div>
        <div>
          <p className="font-mono text-xs uppercase tracking-[0.18em] text-muted-foreground">Contacto</p>
          {contact?.email ? (
            <a href={`mailto:${contact.email}`} className="mt-3 block break-all text-sm text-foreground/80 hover:text-gold">
              {contact.email}
            </a>
          ) : null}
          {contact?.location ? <p className="mt-2 text-sm text-muted-foreground">{contact.location}</p> : null}
          {contact?.socials.length ? (
            <ul className="mt-3 flex flex-wrap gap-3 text-sm">
              {contact.socials.map((s) => (
                <li key={s.key}>
                  <a href={s.href} target="_blank" rel="noreferrer" className="text-foreground/80 hover:text-gold">
                    {s.label}
                  </a>
                </li>
              ))}
            </ul>
          ) : null}
        </div>
      </div>
      <div className="border-t border-border">
        <p className="mx-auto max-w-6xl px-4 py-5 font-mono text-xs text-muted-foreground sm:px-6">
          © {new Date().getFullYear()} GUAPA · Universidad Nacional Autónoma de México
        </p>
      </div>
    </footer>
  );
}
