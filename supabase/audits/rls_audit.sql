SELECT
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced,
  COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'name', p.policyname,
          'command', p.cmd,
          'roles', p.roles,
          'using', p.qual,
          'check', p.with_check
        )
        ORDER BY p.policyname
      )
      FROM pg_policies p
      WHERE p.schemaname = 'public'
        AND p.tablename = c.relname
    ),
    '[]'::jsonb
  ) AS policies,
  COALESCE(
    (
      SELECT jsonb_agg(g.privilege_type ORDER BY g.privilege_type)
      FROM information_schema.role_table_grants g
      WHERE g.table_schema = 'public'
        AND g.table_name = c.relname
        AND g.grantee = 'anon'
    ),
    '[]'::jsonb
  ) AS anon_grants,
  COALESCE(
    (
      SELECT jsonb_agg(g.privilege_type ORDER BY g.privilege_type)
      FROM information_schema.role_table_grants g
      WHERE g.table_schema = 'public'
        AND g.table_name = c.relname
        AND g.grantee = 'authenticated'
    ),
    '[]'::jsonb
  ) AS authenticated_grants
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p')
ORDER BY c.relname;
