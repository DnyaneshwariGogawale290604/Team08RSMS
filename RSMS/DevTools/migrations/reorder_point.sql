-- Migration to add Reorder Point (ROP) and Reorder Quantity (ROQ) baselines to products

ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS reorder_point INTEGER DEFAULT 5,
ADD COLUMN IF NOT EXISTS reorder_quantity INTEGER DEFAULT 20;

-- Optional: Comment describing the columns
COMMENT ON COLUMN public.products.reorder_point IS 'The threshold stock level that triggers an automatic vendor purchase order.';
COMMENT ON COLUMN public.products.reorder_quantity IS 'The target quantity to order when stock falls below the reorder_point.';
