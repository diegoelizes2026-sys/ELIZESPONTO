-- SEU ELIZES PONTO — folha completa. Rode UMA VEZ: Supabase > SQL Editor > New query > Run
-- (rode também o SQL-fotos.sql, se ainda não rodou)
create table if not exists public.se_ponto_ocorrencias(
  id uuid primary key default gen_random_uuid(), funcionario_id uuid not null, data date not null,
  tipo text, observacao text, criado_por uuid, criado_em timestamptz default now(), unique(funcionario_id,data));
create table if not exists public.se_ponto_historico(
  id uuid primary key default gen_random_uuid(), funcionario_id uuid not null, data date not null,
  campo text, anterior text, novo text, motivo text, alterado_por uuid, criado_em timestamptz default now());
create table if not exists public.se_ponto_fechamentos(
  id uuid primary key default gen_random_uuid(), funcionario_id uuid not null, mes text not null,
  fechado_por uuid, fechado_em timestamptz default now(), unique(funcionario_id,mes));
do $$ declare t text; begin
 foreach t in array array['se_ponto_ocorrencias','se_ponto_historico','se_ponto_fechamentos'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('drop policy if exists "%s_owner" on public.%I',t,t);
  execute format('create policy "%s_owner" on public.%I for all to authenticated using (exists (select 1 from public.se_ponto_funcionarios f join public.se_ponto_empresas e on e.id=f.empresa_id where f.id=%I.funcionario_id and e.owner_user_id=auth.uid())) with check (exists (select 1 from public.se_ponto_funcionarios f join public.se_ponto_empresas e on e.id=f.empresa_id where f.id=%I.funcionario_id and e.owner_user_id=auth.uid()))',t,t,t,t);
 end loop; end $$;
-- administrador pode corrigir/criar registros de ponto das suas funcionárias
drop policy if exists "se_ponto_reg_owner_write" on public.se_ponto_registros;
create policy "se_ponto_reg_owner_write" on public.se_ponto_registros for all to authenticated
 using (exists (select 1 from public.se_ponto_funcionarios f join public.se_ponto_empresas e on e.id=f.empresa_id where f.id=se_ponto_registros.funcionario_id and e.owner_user_id=auth.uid()))
 with check (exists (select 1 from public.se_ponto_funcionarios f join public.se_ponto_empresas e on e.id=f.empresa_id where f.id=se_ponto_registros.funcionario_id and e.owner_user_id=auth.uid()));
