-- =============================================
-- RSMS Supply Chain Workflow — Supabase Migrations
-- Run ALL statements below in your Supabase SQL Editor (in order)
-- =============================================

-- ① Extend shipments table with ASN & carrier details
ALTER TABLE shipments
  ADD COLUMN IF NOT EXISTS asn_number        TEXT,
  ADD COLUMN IF NOT EXISTS carrier           TEXT,
  ADD COLUMN IF NOT EXISTS tracking_number   TEXT,
  ADD COLUMN IF NOT EXISTS estimated_delivery TEXT,   -- ISO date "YYYY-MM-DD"
  ADD COLUMN IF NOT EXISTS notes             TEXT,
  ADD COLUMN IF NOT EXISTS has_grn           BOOLEAN DEFAULT FALSE;

-- ② Extend vendor_orders with product + notes columns
ALTER TABLE vendor_orders
  ADD COLUMN IF NOT EXISTS product_id  UUID REFERENCES products(product_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS notes       TEXT;

-- ③ Create the warehouse_inventory table
--    Tracks physical stock per product per warehouse.
CREATE TABLE IF NOT EXISTS warehouse_inventory (
  inventory_id  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id  UUID         NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
  product_id    UUID         REFERENCES products(product_id) ON DELETE SET NULL,
  quantity      INT          NOT NULL DEFAULT 0,
  updated_at    TIMESTAMPTZ  DEFAULT NOW(),
  UNIQUE(warehouse_id, product_id)        -- one row per warehouse+product pair
);

-- ④ Create the Goods Received Notes table
CREATE TABLE IF NOT EXISTS goods_received_notes (
  grn_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id       UUID         REFERENCES shipments(shipment_id) ON DELETE CASCADE,
  request_id        UUID         REFERENCES product_requests(request_id) ON DELETE SET NULL,
  received_by       UUID         REFERENCES users(user_id) ON DELETE SET NULL,
  received_at       TIMESTAMPTZ  DEFAULT NOW(),
  quantity_received INT          NOT NULL,
  condition         TEXT         DEFAULT 'good' CHECK (condition IN ('good', 'damaged', 'partial')),
  notes             TEXT,
  grn_number        TEXT         UNIQUE,
  created_at        TIMESTAMPTZ  DEFAULT NOW()
);

-- ⑤ Performance indexes
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_wh       ON warehouse_inventory(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_product  ON warehouse_inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_grn_shipment_id              ON goods_received_notes(shipment_id);
CREATE INDEX IF NOT EXISTS idx_shipments_dest_store         ON shipments(destination_store_id);
CREATE INDEX IF NOT EXISTS idx_shipments_source_wh          ON shipments(source_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_vendor_orders_vendor         ON vendor_orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_orders_product        ON vendor_orders(product_id);
CREATE INDEX IF NOT EXISTS idx_product_requests_status      ON product_requests(status);

-- ⑥ (Optional) Seed test warehouse inventory
-- INSERT INTO warehouse_inventory (warehouse_id, product_id, quantity)
-- SELECT '<your-warehouse-uuid>', product_id, 100 FROM products WHERE is_active = true;
