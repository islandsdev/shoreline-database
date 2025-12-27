alter table "public"."invoices" drop column "hosted_invoice_url";
alter table "public"."invoices" drop column "invoice_pdf"       ;
alter table "public"."invoices" drop column "stripe_created_at" ;
alter table "public"."invoices" drop column "stripe_customer_id";
alter table "public"."invoices" drop column "stripe_invoice_id" ;