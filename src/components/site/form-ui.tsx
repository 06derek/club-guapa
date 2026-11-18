import { forwardRef, type ReactNode, type SelectHTMLAttributes } from "react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

export function FormCard({ title, icon: Icon, children, className }: { title: string; icon: LucideIcon; children: ReactNode; className?: string }) {
  return (
    <div className={cn("min-w-0 rounded-xl border border-border bg-card p-5 shadow-card sm:p-6", className)}>
      <h3 className="flex items-center gap-2 font-semibold">
        <Icon className="size-4 text-gold" aria-hidden /> {title}
      </h3>
      <div className="mt-5">{children}</div>
    </div>
  );
}

export function FormAlert({ children }: { children: ReactNode }) {
  return (
    <p role="alert" className="rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm text-destructive">
      {children}
    </p>
  );
}

export const NativeSelect = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(
  ({ className, children, ...props }, ref) => (
    <select
      ref={ref}
      className={cn(
        "flex h-9 w-full rounded-md border border-input bg-transparent px-3 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:opacity-50",
        "[&>option]:bg-popover [&>option]:text-popover-foreground",
        className,
      )}
      {...props}
    >
      {children}
    </select>
  ),
);
NativeSelect.displayName = "NativeSelect";

export function EmptyState({ children }: { children: ReactNode }) {
  return <p className="rounded-xl border border-dashed border-border bg-card/50 px-5 py-8 text-center text-sm text-muted-foreground">{children}</p>;
}
