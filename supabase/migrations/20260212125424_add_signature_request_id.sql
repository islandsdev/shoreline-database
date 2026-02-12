alter table "public"."new_documents" drop column "file_url";

alter table "public"."new_documents" add column "signature_request_id" character varying;