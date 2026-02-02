CREATE UNIQUE INDEX documents_unique_file_path ON public.documents USING btree (file_path);

alter table "public"."documents" add constraint "documents_unique_file_path" UNIQUE using index "documents_unique_file_path";