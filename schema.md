-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.associate_product_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sales_associate_id uuid NOT NULL,
  product_id uuid NOT NULL,
  requested_quantity integer NOT NULL DEFAULT 1,
  status USER-DEFINED DEFAULT 'pending'::assoc_request_status_enum,
  manager_id uuid,
  notes text,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT associate_product_requests_pkey PRIMARY KEY (id),
  CONSTRAINT associate_product_requests_sales_associate_id_fkey FOREIGN KEY (sales_associate_id) REFERENCES public.sales_associates(user_id),
  CONSTRAINT associate_product_requests_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id),
  CONSTRAINT associate_product_requests_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES public.boutique_managers(user_id)
);
CREATE TABLE public.associate_ratings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sales_associate_id uuid,
  rating_value numeric CHECK (rating_value >= 1::numeric AND rating_value <= 5::numeric),
  customer_id uuid,
  feedback_text text,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT associate_ratings_pkey PRIMARY KEY (id),
  CONSTRAINT associate_ratings_sales_associate_id_fkey FOREIGN KEY (sales_associate_id) REFERENCES public.sales_associates(user_id),
  CONSTRAINT associate_ratings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id)
);
CREATE TABLE public.batches (
  batch_id uuid NOT NULL DEFAULT gen_random_uuid(),
  vendor_order_id uuid,
  product_id uuid,
  quantity integer,
  warehouse_id uuid,
  received_at timestamp without time zone,
  CONSTRAINT batches_pkey PRIMARY KEY (batch_id),
  CONSTRAINT batches_vendor_order_id_fkey FOREIGN KEY (vendor_order_id) REFERENCES public.vendor_orders(vendor_order_id),
  CONSTRAINT batches_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id),
  CONSTRAINT batches_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(warehouse_id)
);
CREATE TABLE public.boutique_managers (
  user_id uuid NOT NULL,
  store_id uuid NOT NULL UNIQUE,
  corporate_admin_id uuid NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT boutique_managers_pkey PRIMARY KEY (user_id),
  CONSTRAINT boutique_managers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT boutique_managers_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id),
  CONSTRAINT boutique_managers_corporate_admin_id_fkey FOREIGN KEY (corporate_admin_id) REFERENCES public.corporate_admins(user_id)
);
CREATE TABLE public.brands (
  brand_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT brands_pkey PRIMARY KEY (brand_id)
);
CREATE TABLE public.corporate_admins (
  user_id uuid NOT NULL,
  brand_id uuid NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT corporate_admins_pkey PRIMARY KEY (user_id),
  CONSTRAINT corporate_admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT corporate_admins_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id)
);
CREATE TABLE public.customer_preferences (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  preferred_brands jsonb,
  preferred_categories jsonb,
  size_details jsonb,
  budget_min numeric,
  budget_max numeric,
  notes text,
  CONSTRAINT customer_preferences_pkey PRIMARY KEY (id),
  CONSTRAINT customer_preferences_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id)
);
CREATE TABLE public.customer_purchase_history (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  order_id uuid,
  total_spent numeric,
  last_purchase_date timestamp without time zone,
  CONSTRAINT customer_purchase_history_pkey PRIMARY KEY (id),
  CONSTRAINT customer_purchase_history_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT customer_purchase_history_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.sales_orders(order_id)
);
CREATE TABLE public.customer_tags (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  tag text,
  CONSTRAINT customer_tags_pkey PRIMARY KEY (id),
  CONSTRAINT customer_tags_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id)
);
CREATE TABLE public.customers (
  customer_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text,
  phone text,
  email text,
  brand_id uuid,
  created_at timestamp without time zone DEFAULT now(),
  gender text,
  date_of_birth date,
  address text,
  nationality text,
  notes text,
  customer_category text DEFAULT 'Regular'::text,
  CONSTRAINT customers_pkey PRIMARY KEY (customer_id),
  CONSTRAINT customers_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id)
);
CREATE TABLE public.inventory_managers (
  user_id uuid NOT NULL,
  warehouse_id uuid NOT NULL UNIQUE,
  corporate_admin_id uuid NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT inventory_managers_pkey PRIMARY KEY (user_id),
  CONSTRAINT inventory_managers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT inventory_managers_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(warehouse_id),
  CONSTRAINT inventory_managers_corporate_admin_id_fkey FOREIGN KEY (corporate_admin_id) REFERENCES public.corporate_admins(user_id)
);
CREATE TABLE public.order_items (
  order_item_id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid,
  product_id uuid,
  quantity integer,
  price_at_purchase numeric,
  CONSTRAINT order_items_pkey PRIMARY KEY (order_item_id),
  CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.sales_orders(order_id),
  CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.order_tracking (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid,
  status text CHECK (status = ANY (ARRAY['packed'::text, 'shipped'::text, 'delivered'::text, 'returned'::text])),
  priority_level text DEFAULT 'low'::text CHECK (priority_level = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text])),
  estimated_delivery date,
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT order_tracking_pkey PRIMARY KEY (id),
  CONSTRAINT order_tracking_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.sales_orders(order_id)
);
CREATE TABLE public.product_requests (
  request_id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid,
  store_id uuid,
  requested_by uuid,
  quantity integer,
  status USER-DEFINED,
  rejection_reason text,
  brand_id uuid,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT product_requests_pkey PRIMARY KEY (request_id),
  CONSTRAINT product_requests_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id),
  CONSTRAINT product_requests_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id),
  CONSTRAINT product_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.boutique_managers(user_id),
  CONSTRAINT product_requests_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id)
);
CREATE TABLE public.product_trends (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid,
  total_sold_count integer DEFAULT 0,
  avg_time_to_sell numeric,
  trend_score numeric,
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT product_trends_pkey PRIMARY KEY (id),
  CONSTRAINT product_trends_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.products (
  product_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text,
  brand_id uuid,
  category text,
  price numeric,
  size_options jsonb,
  is_active boolean DEFAULT true,
  created_at timestamp without time zone DEFAULT now(),
  making_price numeric,
  image_url text,
  sku text,
  tax numeric DEFAULT (price * 0.18),
  total_price numeric DEFAULT (price * 1.18),
  CONSTRAINT products_pkey PRIMARY KEY (product_id),
  CONSTRAINT products_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id)
);
CREATE TABLE public.receipts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid,
  receipt_url text,
  generated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT receipts_pkey PRIMARY KEY (id),
  CONSTRAINT receipts_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.sales_orders(order_id)
);
CREATE TABLE public.sales_associates (
  user_id uuid NOT NULL,
  store_id uuid NOT NULL,
  boutique_manager_id uuid NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT sales_associates_pkey PRIMARY KEY (user_id),
  CONSTRAINT sales_associates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT sales_associates_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id),
  CONSTRAINT sales_associates_boutique_manager_id_fkey FOREIGN KEY (boutique_manager_id) REFERENCES public.boutique_managers(user_id)
);
CREATE TABLE public.sales_metrics (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sales_associate_id uuid,
  date date NOT NULL,
  total_sales_amount numeric DEFAULT 0,
  target_amount numeric DEFAULT 0,
  achievement_percentage numeric DEFAULT 
CASE
    WHEN (target_amount > (0)::numeric) THEN ((total_sales_amount / target_amount) * (100)::numeric)
    ELSE (0)::numeric
END,
  number_of_orders integer DEFAULT 0,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT sales_metrics_pkey PRIMARY KEY (id),
  CONSTRAINT sales_metrics_sales_associate_id_fkey FOREIGN KEY (sales_associate_id) REFERENCES public.sales_associates(user_id)
);
CREATE TABLE public.sales_orders (
  order_id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  sales_associate_id uuid,
  store_id uuid,
  total_amount numeric,
  status USER-DEFINED,
  created_at timestamp without time zone DEFAULT now(),
  rating_value integer,
  rating_feedback text,
  CONSTRAINT sales_orders_pkey PRIMARY KEY (order_id),
  CONSTRAINT sales_orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT sales_orders_sales_associate_id_fkey FOREIGN KEY (sales_associate_id) REFERENCES public.sales_associates(user_id),
  CONSTRAINT sales_orders_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id)
);
CREATE TABLE public.shipments (
  shipment_id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id uuid,
  batch_id uuid,
  source_warehouse_id uuid,
  destination_store_id uuid,
  status USER-DEFINED,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT shipments_pkey PRIMARY KEY (shipment_id),
  CONSTRAINT shipments_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.product_requests(request_id),
  CONSTRAINT shipments_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.batches(batch_id),
  CONSTRAINT shipments_source_warehouse_id_fkey FOREIGN KEY (source_warehouse_id) REFERENCES public.warehouses(warehouse_id),
  CONSTRAINT shipments_destination_store_id_fkey FOREIGN KEY (destination_store_id) REFERENCES public.stores(store_id)
);
CREATE TABLE public.store_inventory (
  inventory_id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid,
  product_id uuid,
  quantity integer,
  updated_at timestamp without time zone,
  CONSTRAINT store_inventory_pkey PRIMARY KEY (inventory_id),
  CONSTRAINT store_inventory_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id),
  CONSTRAINT store_inventory_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.store_inventory_baseline (
  baseline_id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid,
  product_id uuid,
  baseline_quantity integer,
  current_quantity integer,
  CONSTRAINT store_inventory_baseline_pkey PRIMARY KEY (baseline_id),
  CONSTRAINT store_inventory_baseline_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id),
  CONSTRAINT store_inventory_baseline_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.stores (
  store_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text,
  location text,
  brand_id uuid,
  sales_target numeric,
  created_at timestamp without time zone DEFAULT now(),
  opening_date date,
  status text DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'inactive'::text, 'under_maintenance'::text])),
  address text,
  CONSTRAINT stores_pkey PRIMARY KEY (store_id),
  CONSTRAINT stores_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id)
);
CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid,
  payment_method text CHECK (payment_method = ANY (ARRAY['cash'::text, 'card'::text, 'upi'::text, 'split'::text])),
  payment_status text CHECK (payment_status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text])),
  amount_paid numeric,
  transaction_time timestamp without time zone DEFAULT now(),
  CONSTRAINT transactions_pkey PRIMARY KEY (id),
  CONSTRAINT transactions_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.sales_orders(order_id)
);
CREATE TABLE public.users (
  user_id uuid NOT NULL,
  name text,
  email text,
  phone text,
  brand_id uuid,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (user_id),
  CONSTRAINT users_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT users_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id)
);
CREATE TABLE public.vendor_orders (
  vendor_order_id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id uuid,
  vendor_id uuid,
  quantity integer,
  status USER-DEFINED,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT vendor_orders_pkey PRIMARY KEY (vendor_order_id),
  CONSTRAINT vendor_orders_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.product_requests(request_id),
  CONSTRAINT vendor_orders_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(vendor_id)
);
CREATE TABLE public.vendor_products (
  vendor_product_id uuid NOT NULL DEFAULT gen_random_uuid(),
  vendor_id uuid,
  product_id uuid,
  CONSTRAINT vendor_products_pkey PRIMARY KEY (vendor_product_id),
  CONSTRAINT vendor_products_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(vendor_id),
  CONSTRAINT vendor_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.vendors (
  vendor_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text,
  contact_info text,
  brand_id uuid,
  CONSTRAINT vendors_pkey PRIMARY KEY (vendor_id),
  CONSTRAINT vendors_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id)
);
CREATE TABLE public.warehouses (
  warehouse_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text,
  location text,
  brand_id uuid,
  created_at timestamp without time zone DEFAULT now(),
  address text,
  status USER-DEFINED DEFAULT 'active'::warehouse_status,
  CONSTRAINT warehouses_pkey PRIMARY KEY (warehouse_id),
  CONSTRAINT warehouses_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id)
);
CREATE TABLE public.wishlists (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  product_id uuid,
  added_at timestamp without time zone DEFAULT now(),
  CONSTRAINT wishlists_pkey PRIMARY KEY (id),
  CONSTRAINT wishlists_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT wishlists_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
