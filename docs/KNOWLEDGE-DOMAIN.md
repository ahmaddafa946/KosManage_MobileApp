# Knowledge Domain — Pengelolaan Rumah Kos

**Produk:** KosManage Mobile  
**Domain:** Operasional dan administrasi rumah kos skala kecil–menengah  
**Platform:** Aplikasi mobile untuk pemilik/pengelola dan penghuni  
**Status dokumen:** Referensi domain untuk analisis kebutuhan dan pengembangan  
**Tanggal akses referensi:** 14 Oktober 2026

## 1. Tujuan Dokumen

Dokumen ini menjelaskan domain masalah yang ditangani KosManage Mobile: pengelolaan kamar, data penghuni, masa sewa, tagihan dan pembayaran, laporan kerusakan, serta ringkasan operasional dan keuangan. Dokumen ini melengkapi PRD dan arsitektur teknis dengan penjelasan mengenai istilah, proses bisnis, aturan data, serta referensi yang mendasarinya.

## 2. Gambaran Domain

Rumah kos menyediakan kamar untuk tempat tinggal sementara dalam jangka waktu yang disepakati oleh pemilik/pengelola dan penghuni. Kegiatan operasionalnya tidak hanya menyewakan kamar, tetapi juga menjaga informasi ketersediaan kamar, mencatat masa tinggal, memantau pembayaran, dan menindaklanjuti masalah fasilitas.

Sejumlah penelitian tentang sistem informasi rumah kos menggambarkan masalah yang serupa pada kasus yang mereka teliti. Rahmatya, Simangunsong, dan Wicaksono (2022) membahas kebutuhan informasi kamar, pembayaran berkala, dan pencatatan biaya pemeliharaan. Mursid dan Arman (2021) mengidentifikasi kendala pencatatan manual untuk mengetahui penghuni, kamar kosong, serta pembayaran yang sudah atau belum dilakukan. Hermawan, Amroni, dan Rofi'i (2025) juga membahas kesulitan pemantauan jatuh tempo dan risiko administrasi ketika pencatatan masih bergantung pada kuitansi kertas. Temuan tersebut berasal dari studi kasus masing-masing, sehingga digunakan sebagai rujukan masalah yang mungkin dijumpai, bukan klaim bahwa semua usaha kos menghadapi kondisi yang sama.

Bagi KosManage Mobile, persoalan tersebut diterjemahkan menjadi satu sumber data operasional agar pemilik dapat memeriksa kondisi kos melalui ponsel, sementara penghuni bisa melihat informasi sewa dan menyampaikan laporan kerusakan melalui akun mereka sendiri.

## 3. Aktor dan Kebutuhannya

### 3.1 Pemilik/pengelola (Owner)

Owner bertanggung jawab atas operasional properti. Kebutuhan utamanya meliputi:

- mengetahui jumlah dan status kamar;
- mencatat atau memperbarui data kamar;
- mengelola profil serta masa sewa penghuni;
- mencatat tagihan dan penerimaan pembayaran;
- memantau tunggakan dan riwayat transaksi;
- melihat ringkasan operasional dan keuangan;
- menerima serta memproses laporan kerusakan.

### 3.2 Penghuni (Tenant)

Tenant menggunakan aplikasi untuk memperoleh informasi terkait sewanya sendiri. Kebutuhan utamanya meliputi:

- melihat kamar dan periode sewa yang terkait dengan akunnya;
- mengetahui tagihan, status pembayaran, dan riwayat transaksi miliknya;
- membuat laporan kerusakan atau masalah fasilitas, termasuk melampirkan foto jika tersedia;
- memantau perkembangan laporan yang telah dibuat;
- memperbarui informasi profil yang diizinkan.

Akses tenant harus dibatasi pada datanya sendiri. Pemisahan tampilan berdasarkan role saja tidak cukup untuk melindungi data; akses tetap perlu ditegakkan pada lapisan backend/database.

## 4. Istilah dan Entitas Inti

| Istilah | Makna dalam domain KosManage |
| --- | --- |
| Properti | Rumah kos atau unit usaha yang dikelola oleh owner. |
| Kamar | Unit yang disewakan, memiliki identitas, harga, fasilitas, catatan, dan status. |
| Penghuni (tenant) | Orang yang terhubung dengan periode sewa tertentu dan kamar yang ditempatinya. |
| Periode sewa | Rentang tanggal mulai dan akhir tinggal sesuai kesepakatan. |
| Tagihan | Kewajiban pembayaran untuk periode tertentu, berisi nominal dan tanggal jatuh tempo. |
| Pembayaran | Catatan uang yang dibayarkan terhadap kewajiban sewa, berikut tanggal, metode, nominal, dan riwayatnya. |
| Laporan maintenance | Catatan masalah fasilitas dari penghuni atau tindak lanjut pengelola. |
| Laporan operasional | Ringkasan kondisi kamar, penghuni, periode sewa, dan maintenance. |
| Laporan keuangan | Ringkasan tagihan, pembayaran yang diterima, dan sisa kewajiban berdasarkan data transaksi. |

Status yang tampil di aplikasi sebaiknya memiliki label teks yang jelas, bukan dibedakan hanya berdasarkan warna. Nilai nominal rupiah perlu ditampilkan dengan format lokal yang mudah dibaca, sementara nilai yang disimpan dan dihitung harus tetap berupa angka yang tervalidasi.

## 5. Proses Bisnis Utama

### 5.1 Pengelolaan kamar

Owner mencatat kamar dan karakteristiknya, kemudian memperbarui statusnya sesuai keadaan operasional. Status yang digunakan aplikasi adalah **tersedia**, **terisi**, dan **maintenance**. Kamar yang sedang ditempati atau dalam kondisi maintenance tidak boleh diperlakukan sebagai kamar kosong yang siap diberikan kepada penghuni baru.

### 5.2 Pengelolaan penghuni dan masa sewa

Data penghuni dikaitkan dengan kamar serta tanggal mulai dan berakhirnya masa sewa. Ketika periode sewa mendekati akhir, informasi ini membantu owner melakukan tindak lanjut. Penghitungan sisa masa sewa didasarkan pada tanggal dan zona waktu operasional yang konsisten, bukan disimpan sebagai angka statis yang cepat kedaluwarsa.

### 5.3 Tagihan dan pembayaran

Tagihan menyatakan jumlah yang harus dibayar dan batas waktunya. Pembayaran mencatat nominal yang diterima serta waktu dan metode pembayaran. Setidaknya ada tiga kondisi yang harus bisa dibedakan: belum dibayar, dibayar sebagian, dan lunas. Kondisi terlambat dapat ditentukan berdasarkan tanggal jatuh tempo dan jumlah kewajiban yang masih belum dibayar.

Riwayat pembayaran harus tetap tersedia untuk penelusuran transaksi dan laporan. Sistem tidak boleh menyatakan pembayaran berhasil hanya karena pengguna menekan tombol. Untuk implementasi produksi, status pembayaran harus didasarkan pada bukti transaksi atau konfirmasi backend yang dapat diverifikasi.

**Batas implementasi saat ini:** alur pembayaran QRIS pada versi aplikasi yang menggunakan simulasi harus diberi label simulasi secara eksplisit dan tidak boleh dianggap sebagai transaksi atau konfirmasi pembayaran sungguhan. QRIS merupakan standar QR Code pembayaran yang ditetapkan Bank Indonesia; integrasi aktual memerlukan penyedia jasa pembayaran dan alur verifikasi yang sesuai.

### 5.4 Laporan maintenance

Penghuni mengirim laporan yang berisi judul, deskripsi, kategori atau prioritas, dan foto jika diperlukan. Owner meninjau laporan dan memperbarui status penanganan, misalnya dari diajukan, sedang ditangani, hingga selesai. Penghuni seharusnya tidak dapat mengubah sendiri laporan menjadi selesai apabila perubahan itu merupakan keputusan pengelola.

Foto maintenance dapat memuat informasi pribadi atau kondisi tempat tinggal. Penyimpanannya perlu dibatasi, aksesnya dikendalikan, dan tautan akses tidak dibuat publik tanpa alasan yang sah.

### 5.5 Laporan operasional dan keuangan

Laporan operasional membantu menjawab pertanyaan seperti kamar mana yang terisi, kamar mana yang perlu perbaikan, dan masa sewa mana yang segera berakhir. Laporan keuangan merangkum tagihan, pembayaran yang tercatat, serta sisa kewajiban dalam periode yang dipilih. Angka laporan perlu diturunkan dari sumber transaksi yang sama dan tidak boleh menghitung tagihan sebagai uang yang sudah diterima.

## 6. Aturan Domain yang Perlu Dijaga

1. Nomor kamar harus unik di dalam properti yang sama.
2. Satu kamar tidak boleh memiliki lebih dari satu penghuni aktif pada waktu yang sama, kecuali produk secara eksplisit mendukung aturan hunian bersama.
3. Kamar berstatus maintenance tidak dapat dialokasikan sebagai kamar siap huni.
4. Riwayat penghuni dan transaksi yang telah terjadi harus tetap terjaga ketika masa sewa berakhir atau profil penghuni dinonaktifkan.
5. Nominal tagihan dan pembayaran harus divalidasi sebagai angka nonnegatif; format tampilan Rupiah tidak boleh mengubah nilai angka yang dikirim ke database.
6. Status pembayaran dan agregat laporan harus mengikuti data transaksi yang tersimpan di backend/database sebagai sumber kebenaran.
7. Owner hanya boleh mengakses properti yang menjadi kewenangannya.
8. Tenant hanya boleh mengakses kamar, tagihan, pembayaran, dan laporan yang memang terkait dengan akunnya.
9. Perubahan status laporan maintenance harus mengikuti alur yang ditentukan dan dicatat secara konsisten.
10. Sistem tidak boleh menampilkan operasi tulis sebagai berhasil sebelum respons backend mengonfirmasi keberhasilannya.

Aturan ini adalah baseline kebutuhan produk. Penerapannya harus diverifikasi terhadap skema database, constraint, trigger, dan kebijakan akses yang benar-benar aktif; dokumen ini sendiri tidak membuktikan bahwa semua kontrol tersebut sudah diterapkan.

## 7. Privasi dan Ketentuan Lokal

Data seperti nama, nomor telepon, identitas, informasi tempat tinggal, riwayat pembayaran, dan foto penghuni perlu diperlakukan sebagai data yang membutuhkan perlindungan. Undang-Undang Republik Indonesia Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi merupakan rujukan hukum nasional yang relevan. Implementasi perlu menerapkan pembatasan akses, pengumpulan data seperlunya, penyimpanan yang aman, serta prosedur penanganan data yang sesuai dengan kewajiban yang berlaku.

Pengelolaan rumah kos juga dapat diatur melalui ketentuan pemerintah daerah. Sebagai contoh, terdapat Peraturan Daerah Kabupaten Klungkung Nomor 2 Tahun 2017 tentang Pengelolaan Rumah Kos. Contoh tersebut bukan aturan yang otomatis berlaku di semua daerah; pemilik kos perlu memeriksa peraturan daerah yang berlaku di lokasi usahanya.

## 8. Ruang Lingkup KosManage Mobile

Berdasarkan domain di atas, KosManage Mobile memprioritaskan administrasi dan pemantauan operasional harian untuk owner serta akses informasi sewa bagi tenant. Aplikasi memanfaatkan backend/database KosManage yang sama sebagai sumber data.

Fokus fitur dalam domain ini:

- autentikasi dan pembatasan akses berdasarkan role;
- data kamar dan status hunian;
- data penghuni dan masa sewa;
- pencatatan tagihan dan pembayaran;
- laporan maintenance beserta foto;
- laporan operasional dan ringkasan keuangan.

Hal yang **tidak boleh diasumsikan sudah tersedia** hanya dari dokumen domain ini: booking marketplace, kontrak digital, notifikasi otomatis, integrasi payment gateway atau QRIS produksi, pembukuan akuntansi lengkap, dan sinkronisasi offline penuh. Fitur-fitur tersebut berada di luar ruang lingkup MVP saat ini kecuali ditambahkan melalui requirement yang disetujui.

## 9. Referensi

1. Rahmatya, M. D., Simangunsong, D. E., & Wicaksono, M. F. (2022). *e-Kos sebagai Sistem Informasi Pengelolaan Kos pada Mazasi’s House*. Jurnal Teknologi dan Informasi, 12(2). https://doi.org/10.34010/jati.v12i2.8027  
   **Relevansi:** pengelolaan informasi kos, pembayaran berkala, dan pencatatan biaya pemeliharaan.

2. Mursid, & Arman. (2021). *Rancang Bangun Sistem Informasi Penyewaan Kos Berbasis Web Pada Kos Panjang Abepura*. Jurnal Teknologi Informasi, 9(1), 1–9. https://ojs.ustj.ac.id/jti/article/view/887  
   **Relevansi:** pencatatan manual kamar, penghuni, dan pembayaran sebagai masalah pada studi kasus.

3. Hermawan, J. N., Amroni, & Rofi’i, I. (2025). *Perancangan Sistem Informasi Manajemen Penyewaan Kamar Kos Berbasis Web pada Hosana Ladies Kost*. Journal Vision Technology (V-TECH), 8(2), 1–9. https://doi.org/10.35141/9b2e2b91  
   **Relevansi:** pemantauan jatuh tempo dan administrasi sewa pada studi kasus rumah kos.

4. Badan Pusat Statistik. *Indikator Perumahan 1993–2025*. https://www.bps.go.id/id/statistics-table/1/MTUzNyMx/housing-indicators-1993-2022.html  
   **Relevansi:** konteks statistik nasional terkait status kepemilikan rumah termasuk kategori kontrak/sewa. Indikator ini bukan statistik khusus jumlah rumah kos.

5. Kementerian Komunikasi dan Digital Republik Indonesia. *Undang-Undang Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi*. https://jdih.komdigi.go.id/produk_hukum/view/id/832/t/crc32/  
   **Relevansi:** dasar hukum untuk pertimbangan pemrosesan dan perlindungan data pribadi.

6. Bank Indonesia. *Quick Response Code Indonesian Standard (QRIS)*. https://www.bi.go.id/id/fungsi-utama/sistem-pembayaran/ritel/kanal-layanan/qris/default.aspx  
   **Relevansi:** definisi resmi QRIS dan konteks ketika produk akan mengembangkan alur pembayaran digital yang nyata.

7. Database Peraturan BPK. *Peraturan Daerah Kabupaten Klungkung Nomor 2 Tahun 2017 tentang Pengelolaan Rumah Kos*. https://peraturan.bpk.go.id/Details/23133/perda-kab-klungkung-no-2-tahun-2017  
   **Relevansi:** contoh bahwa pengelolaan rumah kos dapat memiliki ketentuan di tingkat daerah. Peraturan yang relevan harus diperiksa berdasarkan lokasi usaha.

---

**Catatan penggunaan:** Dokumen ini adalah ringkasan domain dan rujukan awal untuk analisis kebutuhan KosManage Mobile, bukan nasihat hukum atau bukti audit implementasi. Aturan yang dibutuhkan pada aplikasi tetap harus dicocokkan dengan proses bisnis pemilik kos, lokasi operasional, serta schema dan kebijakan backend yang aktif.
