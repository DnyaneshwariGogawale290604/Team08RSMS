-- =============================================
-- RSMS Supply Chain Workflow — Supabase Migrations
-- Run these in your Supabase SQL Editor
-- =============================================

-- 1. Extend the shipments table with ASN & carrier details
ALTER TABLE shipments
  ADD COLUMN IF NOT EXISTS asn_number    TEXT,
  ADD COLUMN IF NOT EXISTS carrier       TEXT,
  ADD COLUMN IF NOT EXISTS tracking_number TEXT,
  ADD COLUMN IF NOT EXISTS estimated_delivery TEXT,   -- ISO date "YYYY-MM-DD"
  ADD COLUMN IF NOT EXISTS notes         TEXT,
  ADD COLUMN IF NOT EXISTS has_grn       BOOLEAN DEFAULT FALSE;

-- 2. Create the Goods Received Notes table
CREATE TABLE IF NOT EXISTS goods_received_notes (
  grn_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id       UUID         REFERENCES shipments(shipment_id) ON DELETE CASCADE,
  request_id        UUID         REFERENCES product_requests(request_id) ON DELETE SET NULL,
  received_by       UUID         REFERENCES users(user_id) ON DELETE SET NULL,
  received_at       TIMESTAMPTZ  DEFAULT NOW(),
  quantity_received INT          NOT NULL,
  condition         TEXT         DEFAULT 'good'  CHECK (condition IN ('good', 'damaged', 'partial')),
  notes             TEXT,
  grn_number        TEXT         UNIQUE,
  created_at        TIMESTAMPTZ  DEFAULT NOW()
);

-- 3. (Optional) Index for fast lookup by shipment
CREATE INDEX IF NOT EXISTS idx_grn_shipment_id ON goods_received_notes(shipment_id);
CREATE INDEX IF NOT EXISTS idx_shipments_dest_store ON shipments(destination_store_id);
CREATE INDEX IF NOT EXISTS idx_shipments_source_wh ON shipments(source_warehouse_id);
