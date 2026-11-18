/// Starter examples for maintenance text classification.
///
/// These are curated development examples, not real user reports and not a
/// validated production dataset. Replace/extend them with reviewed,
/// anonymized and manually labelled reports before measuring production quality.
class MaintenanceTrainingExample {
  const MaintenanceTrainingExample(this.category, this.text);

  /// Must match the maintenance_reports.category database constraint.
  final String category;
  final String text;
}

const maintenanceTrainingExamples = <MaintenanceTrainingExample>[
  // AC
  MaintenanceTrainingExample('AC', 'ac tidak dingin pendingin menyala tetapi udara tetap panas'),
  MaintenanceTrainingExample('AC', 'freon ac habis udara kamar tidak sejuk dan ac hanya meniup angin'),
  MaintenanceTrainingExample('AC', 'remote ac rusak tidak bisa menyalakan atau mengatur suhu pendingin'),
  MaintenanceTrainingExample('AC', 'unit indoor ac bocor meneteskan air ke lantai kamar'),
  MaintenanceTrainingExample('AC', 'ac mengeluarkan suara berisik dari unit outdoor saat dinyalakan'),
  MaintenanceTrainingExample('AC', 'ac mati total tidak merespons tombol remote dan tidak menyala'),

  // Electrical
  MaintenanceTrainingExample('electrical', 'lampu kamar mati dan tidak menyala walaupun saklar ditekan'),
  MaintenanceTrainingExample('electrical', 'stop kontak panas mengeluarkan bau terbakar dan diduga korsleting'),
  MaintenanceTrainingExample('electrical', 'kabel listrik terkelupas dan percikan api muncul dari sambungan'),
  MaintenanceTrainingExample('electrical', 'mc b atau breaker turun listrik kamar sering mati'),
  MaintenanceTrainingExample('electrical', 'saklar lampu rusak dan lampu berkedip ketika dinyalakan'),
  MaintenanceTrainingExample('electrical', 'meteran listrik bermasalah token masuk tetapi listrik tidak mengalir'),

  // Plumbing
  MaintenanceTrainingExample('plumbing', 'pipa bocor air terus menetes dari saluran kamar mandi'),
  MaintenanceTrainingExample('plumbing', 'keran air rusak tidak bisa ditutup dan air mengalir terus'),
  MaintenanceTrainingExample('plumbing', 'toilet wc mampet air tidak turun saat disiram'),
  MaintenanceTrainingExample('plumbing', 'saluran pembuangan tersumbat dan air menggenang di kamar mandi'),
  MaintenanceTrainingExample('plumbing', 'shower bocor dan tekanan air dari keran sangat kecil'),
  MaintenanceTrainingExample('plumbing', 'wastafel tersumbat air tidak bisa mengalir ke pembuangan'),

  // Furniture
  MaintenanceTrainingExample('furniture', 'kasur rusak rangka ranjang patah dan tidak kuat menahan beban'),
  MaintenanceTrainingExample('furniture', 'meja kamar patah dan permukaannya sudah tidak stabil'),
  MaintenanceTrainingExample('furniture', 'kursi goyang dan salah satu kaki kursi terlepas'),
  MaintenanceTrainingExample('furniture', 'lemari rusak pintu lemari lepas dari engsel'),
  MaintenanceTrainingExample('furniture', 'gagang pintu dan engsel pintu kamar longgar atau terlepas'),
  MaintenanceTrainingExample('furniture', 'jendela macet tidak bisa dibuka dan relnya rusak'),

  // Internet
  MaintenanceTrainingExample('internet', 'wifi kos tidak bisa tersambung dari ponsel dan laptop'),
  MaintenanceTrainingExample('internet', 'router wifi mati lampu indikator tidak menyala'),
  MaintenanceTrainingExample('internet', 'sinyal wifi sangat lemah dan koneksi internet sering putus'),
  MaintenanceTrainingExample('internet', 'internet lambat tidak bisa membuka situs atau mengikuti kelas online'),
  MaintenanceTrainingExample('internet', 'modem kehilangan koneksi dan indikator jaringan berkedip merah'),
  MaintenanceTrainingExample('internet', 'access point tidak memancarkan jaringan wifi di lantai dua'),

  // Other
  MaintenanceTrainingExample('other', 'kamar kotor lantai berdebu dan sampah belum dibersihkan'),
  MaintenanceTrainingExample('other', 'banyak kecoa semut dan tikus muncul di dalam kamar'),
  MaintenanceTrainingExample('other', 'dinding kamar berjamur lembap dan berbau tidak sedap'),
  MaintenanceTrainingExample('other', 'cat dinding mengelupas dan plafon terlihat bernoda'),
  MaintenanceTrainingExample('other', 'sampah menumpuk di area bersama dan menimbulkan bau'),
  MaintenanceTrainingExample('other', 'kamar perlu dibersihkan karena banyak debu dan kotoran'),
];

const maintenanceCategoryValues = <String>[
  'AC',
  'electrical',
  'plumbing',
  'furniture',
  'internet',
  'other',
];
