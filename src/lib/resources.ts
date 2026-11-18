import { queryOptions } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export const categoriesQuery = queryOptions({
  queryKey: ["public", "resource-categories"],
  queryFn: async () => {
    const { data, error } = await supabase.from("resource_categories").select("id, name, sort_order").order("sort_order").order("name");
    if (error) throw error;
    return data;
  },
});

/** RLS decide qué se ve: visitantes solo públicos, miembros todo. La clave incluye la sesión. */
export const resourcesQuery = (userId: string | null) =>
  queryOptions({
    queryKey: ["public", "resources", userId ?? "anon"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("resources")
        .select("id, title, description, url, category_id, visibility, created_at, resource_categories(name)")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data.map((r) => ({ ...r, categoryName: r.resource_categories?.name ?? null }));
    },
  });
