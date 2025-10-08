# GarmentPay Hub (Anonymous Sign-In + Admin)

Aplikasi internal untuk konveksi dengan **login karyawan tanpa email (Anonymous Sign-In)** dan **admin via email/password**, menggunakan Supabase Auth + RLS. Deploy statis di Vercel.

## Simpan di GitHub (root repo)
```
index.html
vercel.json
garmentpay_schema_secure.sql
README.md
```

## Jalankan di Supabase
- Upload / jalankan **garmentpay_schema_secure.sql** di **SQL Editor** (sekali saja).
- Auth → Providers: **Enable Anonymous Sign-In** (ON). Email boleh OFF jika hanya admin yang pakai.
- Project Settings → URL: isi **Site URL** (domain Vercel).

## Alur
- **Karyawan**: klik "Masuk sebagai Karyawan (Tanpa Email)" → dibuat akun anonymous → admin tautkan ke worker via panel admin → karyawan melihat datanya sendiri (RLS).
- **Admin**: klik "Masuk sebagai Admin", login pakai email/password → kelola data + panel tautkan akun anonim.

Promosikan admin & tautkan karyawan (opsional via SQL):
```sql
update profiles set role='admin' where email='owner@contoh.com';
update profiles set worker_id = (select id from workers where name='Budi')
where id = 'UUID_USER_ANON_BUDI';
```

## Catatan
- Session anonymous disimpan di device. Ganti HP? login anonim lagi → admin tautkan ulang.
- Jangan pernah taruh service_role key di client.
- Jika karyawan **tidak boleh** input `work_logs`, hapus policy `work_logs_employee_insert_own` dari schema.
