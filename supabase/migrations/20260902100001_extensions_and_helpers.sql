-- Phase 2 — Database Foundation
-- 20260902100001_extensions_and_helpers.sql
--
-- 目的：啟用必要 extension，並建立本階段起、後續所有 Phase 都會重複使用的
-- 共用輔助函式與 trigger 函式。這些函式本身不含任何業務資料表，純粹是
-- 「基礎設施」，對應 PHASE_0_AUDIT_REPORT.md 第 4.3.5 節 RLS Strategy
-- 提到的 `is_admin()` SECURITY DEFINER 輔助函式。

-- pgcrypto：Supabase 專案預設會啟用，這裡明確聲明以確保 gen_random_uuid()
-- 在任何環境（含未內建此函式的極舊 Postgres）都可用；PostgreSQL 13+ 核心
-- 已原生支援 gen_random_uuid()，此處啟用純為與 Supabase 預設環境保持一致。
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- set_updated_at()
--
-- 通用 BEFORE UPDATE trigger 函式：任何資料表只要掛上這個 trigger，
-- 每次 UPDATE 都會自動把 updated_at 設為 now()，不需要在應用層或每個 RPC
-- 各自處理，避免遺漏。
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_updated_at() IS
  '通用 BEFORE UPDATE trigger：自動維護 updated_at 欄位，供 Phase 2 起所有主檔資料表共用。';

-- 註：is_admin() 需要查詢 user_roles 表，PostgreSQL 的 SQL-language 函式在
-- CREATE FUNCTION 當下就會做 parse-analyze（需要被參照的資料表已存在），
-- 因此 is_admin() 改放在建立 user_roles 表之後的
-- 20260902100002_profiles_and_roles.sql 檔案末尾，而不是這裡。
