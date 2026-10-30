-- SEU ELIZES PONTO — SEGURANÇA: profissional NUNCA acessa a administração.
-- Rode UMA VEZ: Supabase > SQL Editor > New query > cole tudo > Run (depois dos outros dois SQL).

-- Funções auxiliares
create or replace function public.se_ponto_meu_func(fid uuid) returns boolean language sql security definer stable set search_path=public as $$
  select exists(select 1 from se_ponto_funcionarios f where f.id=fid and f.auth_user_id=auth.uid()) $$;
create or replace function public.se_ponto_admin_do_func(fid uuid) returns boolean language sql security definer stable set search_path=public as $$
  select exists(select 1 from se_ponto_funcionarios f join se_ponto_empresas e on e.id=f.empresa_id where f.id=fid and e.owner_user_id=auth.uid()) $$;

-- 1) Só pode existir UM administrador, e ele não pode ser profissional
create or replace function public.se_ponto_bloqueia_admin() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if exists(select 1 from se_ponto_funcionarios where auth_user_id=new.owner_user_id) then
    raise exception 'Cadastro profissional não pode ser administrador.'; end if;
  if exists(select 1 from se_ponto_empresas) then
    raise exception 'Já existe um administrador cadastrado. Peça acesso a ele.'; end if;
  return new; end $$;
drop trigger if exists se_ponto_bloqueia_admin_t on public.se_ponto_empresas;
create trigger se_ponto_bloqueia_admin_t before insert on public.se_ponto_empresas for each row execute function public.se_ponto_bloqueia_admin();

-- 2) O administrador não pode ser cadastrado como profissional
create or replace function public.se_ponto_bloqueia_prof() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.auth_user_id is not null and exists(select 1 from se_ponto_empresas where owner_user_id=new.auth_user_id) then
    raise exception 'O administrador não pode ser cadastrado como profissional.'; end if;
  return new; end $$;
drop trigger if exists se_ponto_bloqueia_prof_t on public.se_ponto_funcionarios;
create trigger se_ponto_bloqueia_prof_t before insert or update of auth_user_id on public.se_ponto_funcionarios for each row execute function public.se_ponto_bloqueia_prof();

-- 3) Regras RESTRITIVAS: profissional só enxerga/altera o que é DELA; administrador só o da sua empresa
drop policy if exists se_r_empresas on public.se_ponto_empresas;
create policy se_r_empresas on public.se_ponto_empresas as restrictive for all to authenticated
  using (owner_user_id=auth.uid()) with check (owner_user_id=auth.uid());
drop policy if exists se_r_funcionarios on public.se_ponto_funcionarios;
create policy se_r_funcionarios on public.se_ponto_funcionarios as restrictive for all to authenticated
  using (auth_user_id=auth.uid() or exists(select 1 from se_ponto_empresas e where e.id=empresa_id and e.owner_user_id=auth.uid()))
  with check (auth_user_id=auth.uid() or exists(select 1 from se_ponto_empresas e where e.id=empresa_id and e.owner_user_id=auth.uid()));
drop policy if exists se_r_registros on public.se_ponto_registros;
create policy se_r_registros on public.se_ponto_registros as restrictive for all to authenticated
  using (se_ponto_meu_func(funcionario_id) or se_ponto_admin_do_func(funcionario_id))
  with check (se_ponto_meu_func(funcionario_id) or se_ponto_admin_do_func(funcionario_id));
drop policy if exists se_r_jornadas on public.se_ponto_jornadas;
create policy se_r_jornadas on public.se_ponto_jornadas as restrictive for all to authenticated
  using (se_ponto_meu_func(funcionario_id) or se_ponto_admin_do_func(funcionario_id))
  with check (se_ponto_meu_func(funcionario_id) or se_ponto_admin_do_func(funcionario_id));
