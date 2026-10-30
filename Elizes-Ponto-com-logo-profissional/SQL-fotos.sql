-- SEU ELIZES PONTO — rode UMA VEZ no Supabase: SQL Editor > New query > cole tudo > Run
-- (necessário para salvar a FOTO das funcionárias e para o painel "Ao vivo" ler as jornadas)

-- 1) Coluna da foto
alter table public.se_ponto_funcionarios add column if not exists foto_url text;

-- 2) Permite que o ADMINISTRADOR (dono da empresa) altere os dados/foto das suas funcionárias
drop policy if exists "se_ponto_func_update_owner" on public.se_ponto_funcionarios;
create policy "se_ponto_func_update_owner" on public.se_ponto_funcionarios
  for update to authenticated
  using (exists (select 1 from public.se_ponto_empresas e
                 where e.id = se_ponto_funcionarios.empresa_id and e.owner_user_id = auth.uid()))
  with check (exists (select 1 from public.se_ponto_empresas e
                 where e.id = se_ponto_funcionarios.empresa_id and e.owner_user_id = auth.uid()));

-- 3) Permite que o ADMINISTRADOR leia as jornadas das suas funcionárias (detecta atraso no "Ao vivo")
drop policy if exists "se_ponto_jornadas_select_owner" on public.se_ponto_jornadas;
create policy "se_ponto_jornadas_select_owner" on public.se_ponto_jornadas
  for select to authenticated
  using (exists (select 1 from public.se_ponto_funcionarios f
                 join public.se_ponto_empresas e on e.id = f.empresa_id
                 where f.id = se_ponto_jornadas.funcionario_id and e.owner_user_id = auth.uid()));

-- 4) (Opcional) Atualização instantânea no "Ao vivo". Se der erro de "já existe", pode ignorar.
do $$ begin
  alter publication supabase_realtime add table public.se_ponto_registros;
exception when others then null; end $$;

-- 5) A PRÓPRIA funcionária pode trocar a sua foto (e somente a foto, nada mais)
create or replace function public.se_ponto_salvar_minha_foto(p_foto text)
returns void language sql security definer set search_path = public as $$
  update public.se_ponto_funcionarios set foto_url = p_foto where auth_user_id = auth.uid();
$$;
revoke all on function public.se_ponto_salvar_minha_foto(text) from public, anon;
grant execute on function public.se_ponto_salvar_minha_foto(text) to authenticated;
