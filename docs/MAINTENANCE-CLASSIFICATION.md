# Smart Maintenance Classification

## Scope

KosManage Owner dapat melihat dua rekomendasi kategori untuk setiap laporan maintenance:
- Multinomial Naive Bayes
- Linear SVM one-vs-rest dengan TF-IDF

Keduanya membaca gabungan judul dan deskripsi. Kategori mengikuti constraint database:
`AC`, `electrical`, `plumbing`, `furniture`, `internet`, dan `other`.

Pemilik tetap menjadi pengambil keputusan. Prediksi tidak mengubah kategori laporan secara otomatis. Pemilik dapat memeriksa kedua saran lalu memilih kategori aktual melalui dropdown pada kartu laporan. Perubahan manual disimpan ke kolom `maintenance_reports.category` melalui Supabase dan tetap tunduk pada RLS.

## Model and data

Contoh pelatihan awal berada di `lib/domain/services/maintenance_training_data.dart`. Isinya adalah contoh buatan untuk membantu implementasi dan uji fungsional; bukan laporan pengguna yang sudah tervalidasi dan bukan dataset produksi. Model dilatih di perangkat dari contoh tersebut.

SVM menggunakan representasi TF-IDF unigram, pendekatan linear one-vs-rest, hinge loss, dan optimisasi Pegasos deterministik. Nilai margin SVM bukan probabilitas. Skor relatif Naive Bayes juga bukan probabilitas terkalibrasi.

## User experience

- Kedua model memberi saran secara berdampingan.
- Bila prediksi sama, UI memberi indikasi bahwa model sependapat.
- Bila prediksi berbeda atau teks tidak cukup informatif, UI meminta pemeriksaan manual.
- Dropdown kategori adalah nilai yang disimpan. Tidak ada prediksi yang otomatis menimpa data laporan.
- Kategori yang dipilih owner tetap dibatasi pada enum yang digunakan database.

## Quality and release limitations

Unit tests memeriksa beberapa kalimat representatif dan perilaku input kosong. Itu membuktikan fungsi dasar, bukan akurasi model di dunia nyata.

Sebelum menyatakan model akurat atau mengandalkannya untuk keputusan operasional:
1. Kumpulkan laporan maintenance yang dianonimkan.
2. Minta label kategori diperiksa manusia.
3. Pisahkan data train dan test secara stratified; jangan menguji pada contoh yang sama dengan data latih.
4. Laporkan precision, recall, F1-score per kategori, macro-F1, accuracy, dan confusion matrix.
5. Tinjau kesalahan klasifikasi dan perbarui dataset secara versioned.

Jangan menampilkan skor akurasi produksi dari starter examples. Sampai dataset nyata selesai divalidasi, fitur ini adalah rekomendasi bantu untuk owner, bukan pengganti pemeriksaan manusia.
