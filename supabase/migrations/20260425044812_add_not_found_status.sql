-- ==============================================================================
-- Migration: Add "Not Found" (غير موجود) Voter Status
-- Created at: 2026-04-25
-- Description: Updates the allowed status enum in the database to include "غير موجود"
-- ==============================================================================

-- 1. إزالة القيد القديم لحالة الناخب
ALTER TABLE voters DROP CONSTRAINT IF EXISTS voters_status_check;

-- 2. إضافة القيد الجديد ليشمل خيار "غير موجود"
ALTER TABLE voters ADD CONSTRAINT voters_status_check 
CHECK (status IN ('لم يصوت', 'تم التصويت', 'رفض', 'غير موجود'));
