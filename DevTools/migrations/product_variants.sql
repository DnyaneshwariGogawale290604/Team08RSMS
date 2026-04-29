-- Product variants for corporate admin catalog.
-- Apply this in Supabase before using the variant image UI.

CREATE TABLE IF NOT EXISTS public.product_variants (
  variant_id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  name text NOT NULL,
  image_urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  info_text text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT product_variants_pkey PRIMARY KEY (variant_id),
  CONSTRAINT product_variants_product_id_fkey
    FOREIGN KEY (product_id) REFERENCES public.products(product_id) ON DELETE CASCADE,
  CONSTRAINT product_variants_image_urls_is_array
    CHECK (jsonb_typeof(image_urls) = 'array')
);

CREATE INDEX IF NOT EXISTS product_variants_product_id_idx
  ON public.product_variants(product_id);

ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS info_text text;
