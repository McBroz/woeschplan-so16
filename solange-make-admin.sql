-- Solange (Wohnung 1) zu Admin befördern
update public.wp_users set is_admin = true where lower(name) = 'solange';
