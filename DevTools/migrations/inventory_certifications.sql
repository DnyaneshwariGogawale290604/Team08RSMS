-- Inventory certificate support for the Items tab.
-- Safe to run on an existing Supabase/Postgres database.

ALTER TABLE public.inventory_items
ADD COLUMN IF NOT EXISTS asset_tag text,
ADD COLUMN IF NOT EXISTS certification_ids uuid[] NOT NULL DEFAULT '{}'::uuid[],
ADD COLUMN IF NOT EXISTS authenticity_status text NOT NULL DEFAULT 'Pending';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'inventory_items_authenticity_status_check'
  ) THEN
    ALTER TABLE public.inventory_items
    ADD CONSTRAINT inventory_items_authenticity_status_check
    CHECK (authenticity_status = ANY (ARRAY['Verified', 'Pending', 'Failed']));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.certifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  item_id text NOT NULL,
  type text NOT NULL DEFAULT 'Authenticity',
  certificate_number text NOT NULL UNIQUE,
  issued_by text NOT NULL,
  issued_date timestamp with time zone NOT NULL DEFAULT now(),
  expiry_date timestamp with time zone,
  document_url text,
  status text NOT NULL DEFAULT 'Valid'
    CHECK (status = ANY (ARRAY['Valid', 'Expired', 'Revoked'])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT certifications_pkey PRIMARY KEY (id),
  CONSTRAINT certifications_item_id_fkey
    FOREIGN KEY (item_id) REFERENCES public.inventory_items(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS certifications_item_id_idx
ON public.certifications(item_id);

-- Seed one reference certificate for each inventory item that does not have one yet.
INSERT INTO public.certifications (
  item_id,
  type,
  certificate_number,
  issued_by,
  issued_date,
  expiry_date,
  document_url,
  status
)
SELECT
  ii.id,
  'Authenticity',
  'CERT-' || regexp_replace(ii.id, '[^A-Za-z0-9]+', '', 'g'),
  'RSMS Certification Authority',
  now() - interval '7 days',
  now() + interval '358 days',
  NULL,
  'Valid'
FROM public.inventory_items ii
WHERE NOT EXISTS (
  SELECT 1
  FROM public.certifications c
  WHERE c.item_id = ii.id
);

WITH latest_certification AS (
  SELECT DISTINCT ON (item_id)
    item_id,
    id,
    certificate_number,
    status,
    expiry_date
  FROM public.certifications
  ORDER BY item_id, created_at DESC
)
UPDATE public.inventory_items ii
SET certificate_id = lc.certificate_number,
    certification_ids = ARRAY[lc.id],
    authenticity_status = CASE
      WHEN lc.status = 'Valid' AND (lc.expiry_date IS NULL OR lc.expiry_date > now()) THEN 'Verified'
      WHEN lc.status = 'Expired' OR (lc.expiry_date IS NOT NULL AND lc.expiry_date <= now()) THEN 'Failed'
      ELSE 'Pending'
    END
FROM latest_certification lc
WHERE lc.item_id = ii.id;

UPDATE public.inventory_items ii
SET certificate_id = NULL,
    certification_ids = '{}'::uuid[],
    authenticity_status = 'Pending'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.certifications c
  WHERE c.item_id = ii.id
);
