export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      activities: {
        Row: {
          activity_date: string
          created_at: string
          created_by: string
          description: string
          id: string
          tag: string
          title: string
        }
        Insert: {
          activity_date: string
          created_at?: string
          created_by?: string
          description: string
          id?: string
          tag: string
          title: string
        }
        Update: {
          activity_date?: string
          created_at?: string
          created_by?: string
          description?: string
          id?: string
          tag?: string
          title?: string
        }
        Relationships: []
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          details: Json
          entity: string
          entity_id: string | null
          id: number
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          details?: Json
          entity: string
          entity_id?: string | null
          id?: never
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          details?: Json
          entity?: string
          entity_id?: string | null
          id?: never
        }
        Relationships: []
      }
      calendar_events: {
        Row: {
          created_at: string
          created_by: string
          description: string | null
          duration_minutes: number | null
          id: string
          platform: string
          starts_at: string
          title: string
          url: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string
          description?: string | null
          duration_minutes?: number | null
          id?: string
          platform: string
          starts_at: string
          title: string
          url?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string
          description?: string | null
          duration_minutes?: number | null
          id?: string
          platform?: string
          starts_at?: string
          title?: string
          url?: string | null
        }
        Relationships: []
      }
      cf_solved_problems: {
        Row: {
          contest_id: number | null
          first_accepted_at: string
          name: string
          problem_index: string
          problem_key: string
          rating: number | null
          tags: string[]
          user_id: string
        }
        Insert: {
          contest_id?: number | null
          first_accepted_at: string
          name: string
          problem_index: string
          problem_key: string
          rating?: number | null
          tags?: string[]
          user_id: string
        }
        Update: {
          contest_id?: number | null
          first_accepted_at?: string
          name?: string
          problem_index?: string
          problem_key?: string
          rating?: number | null
          tags?: string[]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "cf_solved_problems_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      codeforces_accounts: {
        Row: {
          avatar_url: string | null
          cf_rank: string | null
          full_synced: boolean
          handle: string
          info_request_id: number | null
          last_synced_at: string | null
          linked_at: string
          max_rank: string | null
          max_rating: number | null
          rating: number | null
          status_request_id: number | null
          sync_error: string | null
          sync_requested_at: string | null
          sync_status: string
          user_id: string
        }
        Insert: {
          avatar_url?: string | null
          cf_rank?: string | null
          full_synced?: boolean
          handle: string
          info_request_id?: number | null
          last_synced_at?: string | null
          linked_at?: string
          max_rank?: string | null
          max_rating?: number | null
          rating?: number | null
          status_request_id?: number | null
          sync_error?: string | null
          sync_requested_at?: string | null
          sync_status?: string
          user_id: string
        }
        Update: {
          avatar_url?: string | null
          cf_rank?: string | null
          full_synced?: boolean
          handle?: string
          info_request_id?: number | null
          last_synced_at?: string | null
          linked_at?: string
          max_rank?: string | null
          max_rating?: number | null
          rating?: number | null
          status_request_id?: number | null
          sync_error?: string | null
          sync_requested_at?: string | null
          sync_status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "codeforces_accounts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      external_platforms: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          name: string
          url: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          url?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          url?: string | null
        }
        Relationships: []
      }
      external_results: {
        Row: {
          contest_date: string
          contest_name: string
          created_at: string
          id: string
          notes: string | null
          participants: number | null
          place: number | null
          platform_id: string
          score: number | null
          solved: number
          updated_at: string
          user_id: string
        }
        Insert: {
          contest_date: string
          contest_name: string
          created_at?: string
          id?: string
          notes?: string | null
          participants?: number | null
          place?: number | null
          platform_id: string
          score?: number | null
          solved: number
          updated_at?: string
          user_id?: string
        }
        Update: {
          contest_date?: string
          contest_name?: string
          created_at?: string
          id?: string
          notes?: string | null
          participants?: number | null
          place?: number | null
          platform_id?: string
          score?: number | null
          solved?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "external_results_platform_id_fkey"
            columns: ["platform_id"]
            isOneToOne: false
            referencedRelation: "external_platforms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "external_results_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          bio: string | null
          created_at: string
          full_name: string
          id: string
          is_active: boolean
          updated_at: string
          username: string
        }
        Insert: {
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          full_name: string
          id: string
          is_active?: boolean
          updated_at?: string
          username: string
        }
        Update: {
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          full_name?: string
          id?: string
          is_active?: boolean
          updated_at?: string
          username?: string
        }
        Relationships: []
      }
      resource_categories: {
        Row: {
          created_at: string
          id: string
          name: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          sort_order?: number
        }
        Relationships: []
      }
      resources: {
        Row: {
          category_id: string | null
          created_at: string
          created_by: string
          description: string
          id: string
          title: string
          updated_at: string
          url: string
          visibility: Database["public"]["Enums"]["resource_visibility"]
        }
        Insert: {
          category_id?: string | null
          created_at?: string
          created_by?: string
          description: string
          id?: string
          title: string
          updated_at?: string
          url: string
          visibility?: Database["public"]["Enums"]["resource_visibility"]
        }
        Update: {
          category_id?: string | null
          created_at?: string
          created_by?: string
          description?: string
          id?: string
          title?: string
          updated_at?: string
          url?: string
          visibility?: Database["public"]["Enums"]["resource_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "resources_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "resource_categories"
            referencedColumns: ["id"]
          },
        ]
      }
      schedules: {
        Row: {
          activity: string
          created_at: string
          created_by: string
          day_of_week: number
          end_time: string
          id: string
          place: string
          start_time: string
        }
        Insert: {
          activity: string
          created_at?: string
          created_by?: string
          day_of_week: number
          end_time: string
          id?: string
          place: string
          start_time: string
        }
        Update: {
          activity?: string
          created_at?: string
          created_by?: string
          day_of_week?: number
          end_time?: string
          id?: string
          place?: string
          start_time?: string
        }
        Relationships: []
      }
      site_settings: {
        Row: {
          key: string
          updated_at: string
          value: string
        }
        Insert: {
          key: string
          updated_at?: string
          value: string
        }
        Update: {
          key?: string
          updated_at?: string
          value?: string
        }
        Relationships: []
      }
      team_members: {
        Row: {
          added_by: string
          joined_at: string
          team_id: string
          user_id: string
        }
        Insert: {
          added_by?: string
          joined_at?: string
          team_id: string
          user_id: string
        }
        Update: {
          added_by?: string
          joined_at?: string
          team_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_members_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      teams: {
        Row: {
          created_at: string
          created_by: string
          description: string | null
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          created_by?: string
          description?: string | null
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          created_by?: string
          description?: string | null
          id?: string
          name?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      cf_enqueue_sync: { Args: { _uid: string }; Returns: undefined }
      cf_process_sync: { Args: { _uid: string }; Returns: string }
      cf_sync_tick: { Args: never; Returns: undefined }
      get_scoreboard: {
        Args: { _from: string; _to: string }
        Returns: {
          cf_rank: string
          full_name: string
          handle: string
          last_solved_at: string
          last_synced_at: string
          rating: number
          solved: number
          sync_status: string
          user_id: string
          username: string
        }[]
      }
      get_team_stats: { Args: { _team: string }; Returns: Json }
      get_user_stats: {
        Args: { _from: string; _to: string; _user: string }
        Returns: Json
      }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      is_active_user: { Args: { _uid: string }; Returns: boolean }
      is_team_member: {
        Args: { _team_id: string; _user_id: string }
        Returns: boolean
      }
      is_unam_email: { Args: { _email: string }; Returns: boolean }
      link_codeforces: { Args: { _handle: string }; Returns: string }
      process_my_cf_sync: { Args: never; Returns: string }
      request_my_cf_sync: { Args: never; Returns: string }
      unlink_codeforces: { Args: never; Returns: undefined }
      update_my_profile: {
        Args: { _bio: string; _full_name: string; _username: string }
        Returns: undefined
      }
      username_available: { Args: { _username: string }; Returns: boolean }
    }
    Enums: {
      app_role: "admin" | "user"
      resource_visibility: "public" | "members"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "user"],
      resource_visibility: ["public", "members"],
    },
  },
} as const
