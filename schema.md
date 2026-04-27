-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.appointment_products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  appointment_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer DEFAULT 1,
  notes text,
  CONSTRAINT appointment_products_pkey PRIMARY KEY (id),
  CONSTRAINT appointment_products_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointments(id),
  CONSTRAINT appointment_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.appointments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL,
  sales_associate_id uuid,
  store_id uuid,
  appointment_at timestamp with time zone NOT NULL,
  duration_mins integer DEFAULT 30,
  status text NOT NULL DEFAULT 'scheduled'::text CHECK (status = ANY (ARRAY['scheduled'::text, 'completed'::text, 'cancelled'::text, 'no_show'::text])),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  linked_order_id uuid,
  amount_paid numeric DEFAULT 0,
  total_amount numeric DEFAULT 0,
  payment_status text DEFAULT 'unpaid'::text CHECK (payment_status = ANY (ARRAY['unpaid'::text, 'partially_paid'::text, 'paid'::text])),
  CONSTRAINT appointments_pkey PRIMARY KEY (id),
  CONSTRAINT appointments_linked_order_id_fkey FOREIGN KEY (linked_order_id) REFERENCES public.sales_orders(order_id),
  CONSTRAINT appointments_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT appointments_sales_associate_id_fkey FOREIGN KEY (sales_associate_id) REFERENCES public.sales_associates(user_id)
);
CREATE TABLE public.associate_product_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sales_associate_id uuid,
  product_id uuid NOT NULL,
  requested_quantity integer NOT NULL DEFAULT 1,
  status USER-DEFINED DEFAULT 'pending'::assoc_request_status_enum,
  manager_id uuid,
  notes text,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT associate_product_requests_pkey PRIMARY KEY (id),
  CONSTRAINT associate_product_requests_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id),
  CONSTRAINT associate_product_requests_sales_associate_id_fkey FOREIGN KEY (sales_associate_id) REFERENCES public.sales_associates(user_id),
  CONSTRAINT associate_product_requests_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES public.boutique_managers(user_id)
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
  corporate_admin_id uuid,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT boutique_managers_pkey PRIMARY KEY (user_id),
  CONSTRAINT boutique_managers_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id),
  CONSTRAINT boutique_managers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT boutique_managers_corporate_admin_id_fkey FOREIGN KEY (corporate_admin_id) REFERENCES public.corporate_admins(user_id)
);
CREATE TABLE public.brands (
  brand_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT brands_pkey PRIMARY KEY (brand_id)
);
CREATE TABLE public.cash_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  brand_id uuid NOT NULL,
  sales_order_id uuid NOT NULL,
  amount numeric NOT NULL,
  tendered numeric,
  change numeric,
  note text,
  recorded_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT cash_records_pkey PRIMARY KEY (id),
  CONSTRAINT cash_records_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id),
  CONSTRAINT cash_records_sales_order_id_fkey FOREIGN KEY (sales_order_id) REFERENCES public.sales_orders(order_id),
  CONSTRAINT cash_records_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.users(user_id)
);
CREATE TABLE public.corporate_admins (
  user_id uuid NOT NULL,
  brand_id uuid NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT corporate_admins_pkey PRIMARY KEY (user_id),
  CONSTRAINT corporate_admins_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id),
  CONSTRAINT corporate_admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id)
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
  email text NOT NULL,
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
CREATE TABLE public.gateway_configs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  brand_id uuid NOT NULL,
  gateway USER-DEFINED NOT NULL DEFAULT 'razorpay'::gateway_type,
  key_id text,
  key_secret_id uuid NOT NULL,
  webhook_secret_id uuid,
  enabled_methods ARRAY DEFAULT ARRAY['upi'::text, 'card'::text, 'netbanking'::text],
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  key_id_vault_id uuid,
  max_payment_legs integer DEFAULT 2 CHECK (max_payment_legs >= 1 AND max_payment_legs <= 3),
  max_leg_splits integer DEFAULT 2 CHECK (max_leg_splits >= 1 AND max_leg_splits <= 3),
  CONSTRAINT gateway_configs_pkey PRIMARY KEY (id),
  CONSTRAINT gateway_configs_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id)
);
CREATE TABLE public.goods_received_notes (
  grn_id uuid NOT NULL DEFAULT gen_random_uuid(),
  shipment_id uuid,
  request_id uuid,
  received_by uuid,
  received_at timestamp with time zone DEFAULT now(),
  quantity_received integer NOT NULL,
  condition text DEFAULT 'good'::text CHECK (condition = ANY (ARRAY['good'::text, 'damaged'::text, 'partial'::text])),
  notes text,
  grn_number text UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT goods_received_notes_pkey PRIMARY KEY (grn_id),
  CONSTRAINT goods_received_notes_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipments(shipment_id),
  CONSTRAINT goods_received_notes_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.product_requests(request_id),
  CONSTRAINT goods_received_notes_received_by_fkey FOREIGN KEY (received_by) REFERENCES public.users(user_id)
);
CREATE TABLE public.inventory_items (
  id text NOT NULL,
  serial_id text NOT NULL,
  product_id uuid NOT NULL,
  batch_no text NOT NULL DEFAULT ''::text,
  certificate_id text,
  product_name text NOT NULL DEFAULT ''::text,
  category text NOT NULL DEFAULT ''::text,
  location text NOT NULL DEFAULT 'Warehouse'::text,
  status text NOT NULL DEFAULT 'Available'::text CHECK (status = ANY (ARRAY['Available'::text, 'Reserved'::text, 'In Transit'::text, 'Under Repair'::text, 'Scrapped'::text, 'Sold'::text])),
  timestamp timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT inventory_items_pkey PRIMARY KEY (id),
  CONSTRAINT inventory_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
);
CREATE TABLE public.inventory_managers (
  user_id uuid NOT NULL,
  warehouse_id uuid NOT NULL UNIQUE,
  corporate_admin_id uuid,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT inventory_managers_pkey PRIMARY KEY (user_id),
  CONSTRAINT inventory_managers_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(warehouse_id),
  CONSTRAINT inventory_managers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id),
  CONSTRAINT inventory_managers_corporate_admin_id_fkey FOREIGN KEY (corporate_admin_id) REFERENCES public.corporate_admins(user_id)
);
CREATE TABLE public.online_customer (
  customer_id uuid NOT NULL,
  name text,
  email text UNIQUE,
  phone text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT online_customer_pkey PRIMARY KEY (customer_id),
  CONSTRAINT online_customer_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES auth.users(id)
);
CREATE TABLE public.order_feedback (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid,
  customer_id uuid,
  sales_associate_id uuid,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  feedback text,
  feedback_token text NOT NULL UNIQUE,
  is_submitted boolean DEFAULT false,
  created_at timestamp without time zone DEFAULT now(),
  submitted_at timestamp without time zone,
  expires_at timestamp without time zone,
  CONSTRAINT order_feedback_pkey PRIMARY KEY (id),
  CONSTRAINT order_feedback_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.sales_orders(order_id),
  CONSTRAINT order_feedback_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT order_feedback_sales_associate_id_fkey FOREIGN KEY (sales_associate_id) REFERENCES public.sales_associates(user_id)
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
CREATE TABLE public.payment_leg_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  payment_leg_id uuid NOT NULL,
  brand_id uuid NOT NULL,
  item_number integer NOT NULL DEFAULT 1 CHECK (item_number >= 1 AND item_number <= 3),
  amount numeric NOT NULL,
  method text NOT NULL CHECK (method = ANY (ARRAY['upi'::text, 'cash'::text, 'netbanking'::text])),
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'cancelled'::text])),
  payment_order_id uuid,
  cash_record_id uuid,
  collected_by uuid,
  collected_at timestamp with time zone,
  note text,
  created_at timestamp with time zone DEFAULT now(),
  receipt_url text,
  CONSTRAINT payment_leg_items_pkey PRIMARY KEY (id),
  CONSTRAINT payment_leg_items_collected_by_fkey FOREIGN KEY (collected_by) REFERENCES public.users(user_id),
  CONSTRAINT payment_leg_items_payment_leg_id_fkey FOREIGN KEY (payment_leg_id) REFERENCES public.payment_legs(id),
  CONSTRAINT payment_leg_items_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id),
  CONSTRAINT payment_leg_items_payment_order_id_fkey FOREIGN KEY (payment_order_id) REFERENCES public.payment_orders(id),
  CONSTRAINT payment_leg_items_cash_record_id_fkey FOREIGN KEY (cash_record_id) REFERENCES public.cash_records(id)
);
CREATE TABLE public.payment_legs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sales_order_id uuid NOT NULL,
  brand_id uuid NOT NULL,
  leg_number integer NOT NULL DEFAULT 1 CHECK (leg_number >= 1 AND leg_number <= 3),
  due_type text NOT NULL DEFAULT 'immediate'::text CHECK (due_type = ANY (ARRAY['immediate'::text, 'on_delivery'::text])),
  total_amount numeric NOT NULL,
  amount_paid numeric DEFAULT 0,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'partially_paid'::text, 'paid'::text, 'cancelled'::text])),
  collected_by uuid,
  collected_at timestamp with time zone,
  note text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT payment_legs_pkey PRIMARY KEY (id),
  CONSTRAINT payment_legs_sales_order_id_fkey FOREIGN KEY (sales_order_id) REFERENCES public.sales_orders(order_id),
  CONSTRAINT payment_legs_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id),
  CONSTRAINT payment_legs_collected_by_fkey FOREIGN KEY (collected_by) REFERENCES public.users(user_id)
);
CREATE TABLE public.payment_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  brand_id uuid NOT NULL,
  sales_order_id uuid NOT NULL,
  gateway USER-DEFINED NOT NULL,
  gateway_order_id text UNIQUE,
  amount numeric NOT NULL,
  currency text DEFAULT 'INR'::text,
  status USER-DEFINED DEFAULT 'pending'::payment_status_type,
  method text,
  expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT payment_orders_pkey PRIMARY KEY (id),
  CONSTRAINT payment_orders_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id),
  CONSTRAINT payment_orders_sales_order_id_fkey FOREIGN KEY (sales_order_id) REFERENCES public.sales_orders(order_id)
);
CREATE TABLE public.payment_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  payment_order_id uuid NOT NULL,
  token text NOT NULL UNIQUE,
  expires_at timestamp with time zone NOT NULL,
  accessed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT payment_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT payment_sessions_payment_order_id_fkey FOREIGN KEY (payment_order_id) REFERENCES public.payment_orders(id)
);
CREATE TABLE public.payment_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  payment_order_id uuid NOT NULL,
  gateway_payment_id text,
  gateway_signature text,
  verified boolean DEFAULT false,
  raw_webhook_payload jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT payment_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT payment_transactions_payment_order_id_fkey FOREIGN KEY (payment_order_id) REFERENCES public.payment_orders(id)
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
  CONSTRAINT product_requests_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id),
  CONSTRAINT product_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.boutique_managers(user_id)
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
CREATE TABLE public.repair_tickets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  item_id text NOT NULL,
  issue_type text NOT NULL,
  description text NOT NULL DEFAULT ''::text,
  status text NOT NULL DEFAULT 'Created'::text CHECK (status = ANY (ARRAY['Created'::text, 'Diagnosed'::text, 'In Repair'::text, 'QA Check'::text, 'Completed'::text, 'Failed'::text, 'Scrapped'::text])),
  assigned_to text,
  eta date,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT repair_tickets_pkey PRIMARY KEY (id),
  CONSTRAINT repair_tickets_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.inventory_items(id)
);
CREATE TABLE public.sales_associates (
  user_id uuid NOT NULL,
  store_id uuid NOT NULL,
  boutique_manager_id uuid,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT sales_associates_pkey PRIMARY KEY (user_id),
  CONSTRAINT sales_associates_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id),
  CONSTRAINT sales_associates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id),
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
  payment_status text DEFAULT 'unpaid'::text CHECK (payment_status = ANY (ARRAY['unpaid'::text, 'partially_paid'::text, 'paid'::text])),
  amount_paid numeric DEFAULT 0,
  appointment_id uuid,
  CONSTRAINT sales_orders_pkey PRIMARY KEY (order_id),
  CONSTRAINT sales_orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id),
  CONSTRAINT sales_orders_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id),
  CONSTRAINT sales_orders_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES public.appointments(id),
  CONSTRAINT sales_orders_sales_associate_id_fkey FOREIGN KEY (sales_associate_id) REFERENCES public.sales_associates(user_id)
);
CREATE TABLE public.shipments (
  shipment_id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id uuid,
  batch_id uuid,
  source_warehouse_id uuid,
  destination_store_id uuid,
  status USER-DEFINED,
  created_at timestamp without time zone DEFAULT now(),
  asn_number text,
  carrier text,
  tracking_number text,
  estimated_delivery text,
  notes text,
  has_grn boolean DEFAULT false,
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
  payment_method text CHECK (payment_method = ANY (ARRAY['cash'::text, 'card'::text, 'upi'::text, 'split'::text, 'netbanking'::text])),
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
  CONSTRAINT users_brand_id_fkey FOREIGN KEY (brand_id) REFERENCES public.brands(brand_id),
  CONSTRAINT users_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.vendor_orders (
  vendor_order_id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id uuid,
  vendor_id uuid,
  quantity integer,
  status USER-DEFINED,
  created_at timestamp without time zone DEFAULT now(),
  product_id uuid,
  notes text,
  CONSTRAINT vendor_orders_pkey PRIMARY KEY (vendor_order_id),
  CONSTRAINT vendor_orders_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.product_requests(request_id),
  CONSTRAINT vendor_orders_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(vendor_id),
  CONSTRAINT vendor_orders_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
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
CREATE TABLE public.warehouse_inventory (
  inventory_id uuid NOT NULL DEFAULT gen_random_uuid(),
  warehouse_id uuid NOT NULL,
  product_id uuid,
  quantity integer NOT NULL DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT warehouse_inventory_pkey PRIMARY KEY (inventory_id),
  CONSTRAINT warehouse_inventory_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(warehouse_id),
  CONSTRAINT warehouse_inventory_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id)
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
