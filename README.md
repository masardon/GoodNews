# Good News adalah Kabar Baik

### Kata Pengantar
Aplikasi ini dibangun untuk memudahkan pengumpulan artikel dari berbagai URL.
Backend menggunakan FastAPI (Python) yang ringan dan cepat, sehingga tidak memerlukan spesifikasi hosting yang tinggi.
Untuk saat ini, aplikasi ini memiliki frontend untuk iOS yang dibangun menggunakan Swift.

### Lisensi
_Siapa pun bebas untuk mengklon dan berkontribusi dalam pengembangan aplikasi ini demi kemanfaatannya bagi pengguna. Namun, publikasi aplikasi ini di toko aplikasi mana pun dengan nama "Kabar Baik" secara eksklusif hanya menjadi hak cipta dari kreator. 
Dengan mengunduh, menggunakan, atau berkontribusi pada aplikasi ini, Anda dianggap telah memahami dan menyetujui ketentuan ini, terlepas dari adanya perjanjian hukum tertulis._

### Cara penggunaan
1. Clone Repository
   ```bash
   git clone https://github.com/masardon/GoodNews.git
2. Jalankan Perintah Docker Compose
   ```bash
   docker compose up -d; docker compose logs -f

Aplikasi ini akan Expose port 8000 jadi tinggal akses API nya menggunakan URL:
```bash
http://localhost:8000/docs
