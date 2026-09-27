import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

/// Etüt salonunun oturma düzeni.
enum StudyRoomSeating {
  /// Her sırada tek kişilik, ayrı kutular.
  single,

  /// Her sırada iki kişilik, yapışık kutular.
  pair,

  /// Köşeli U düzeni; iki bacak ve taban.
  horseshoe,

  /// Grup çalışma masaları.
  groupTables,
}

extension StudyRoomSeatingLabel on StudyRoomSeating {
  String get label {
    switch (this) {
      case StudyRoomSeating.single:
        return 'Tekli Sıra';
      case StudyRoomSeating.pair:
        return 'Çiftli Sıra';
      case StudyRoomSeating.horseshoe:
        return 'U Tipi';
      case StudyRoomSeating.groupTables:
        return 'Grup Çalışma Masası';
    }
  }

  String get value => name;

  /// Bu düzende masa kaç kişilik sorusunun sorulması gerekir.
  bool get asksTableSize => this == StudyRoomSeating.groupTables;
}

StudyRoomSeating studyRoomSeatingFromValue(String value) {
  return StudyRoomSeating.values.firstWhere(
    (seating) => seating.value == value,
    orElse: () => StudyRoomSeating.single,
  );
}

/// Salonun kaç kişilik olduğu, oturma düzenine göre otomatik hesaplanır.
class StudyRoomLayout {
  const StudyRoomLayout({
    this.columns = defaultColumns,
    this.rows = defaultRows,
    this.uLeftSeats = defaultULegSeats,
    this.uRightSeats = defaultULegSeats,
    this.uBaseSeats = defaultUBaseSeats,
    this.tableColumns = defaultTableColumns,
    this.tableRows = defaultTableRows,
  });

  /// Tekli sıra varsayılanı 5 x 4 = 20 kişi.
  static const defaultColumns = 5;
  static const defaultRows = 4;

  /// Çiftli sıra varsayılanı 5 x 2 x 2 = 20 kişi.
  static const defaultPairColumns = 5;
  static const defaultPairRows = 2;

  /// U düzeni varsayılanı 5 + 10 + 5 = 20 kişi.
  static const defaultULegSeats = 5;
  static const defaultUBaseSeats = 10;

  /// Grup masası varsayılanı 2 x 2 masa.
  static const defaultTableColumns = 2;
  static const defaultTableRows = 2;

  /// Yana doğru kaç sıra var.
  final int columns;

  /// Geriye doğru kaç sıra var.
  final int rows;

  /// U düzeninde sol bacaktaki sandalye sayısı.
  final int uLeftSeats;

  /// U düzeninde sağ bacaktaki sandalye sayısı.
  final int uRightSeats;

  /// U düzeninde tabandaki sandalye sayısı.
  final int uBaseSeats;

  /// Grup düzeninde yatay masa sayısı.
  final int tableColumns;

  /// Grup düzeninde dikey masa sayısı.
  final int tableRows;

  static StudyRoomLayout defaultsFor(StudyRoomSeating seating) {
    switch (seating) {
      case StudyRoomSeating.single:
        return const StudyRoomLayout(
          columns: defaultColumns,
          rows: defaultRows,
        );
      case StudyRoomSeating.pair:
        return const StudyRoomLayout(
          columns: defaultPairColumns,
          rows: defaultPairRows,
        );
      case StudyRoomSeating.horseshoe:
        return const StudyRoomLayout();
      case StudyRoomSeating.groupTables:
        return const StudyRoomLayout();
    }
  }

  /// Düzenin ürettiği kapasite.
  int capacityOf(
    StudyRoomSeating seating, {
    int tableSize = 4,
    bool tableHeads = false,
  }) {
    switch (seating) {
      case StudyRoomSeating.single:
        return columns * rows;
      case StudyRoomSeating.pair:
        return columns * rows * 2;
      case StudyRoomSeating.horseshoe:
        return uLeftSeats + uRightSeats + uBaseSeats;
      case StudyRoomSeating.groupTables:
        final perTable = tableSize + (tableHeads ? 2 : 0);
        return tableColumns * tableRows * perTable;
    }
  }

  StudyRoomLayout copyWith({
    int? columns,
    int? rows,
    int? uLeftSeats,
    int? uRightSeats,
    int? uBaseSeats,
    int? tableColumns,
    int? tableRows,
  }) {
    return StudyRoomLayout(
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      uLeftSeats: uLeftSeats ?? this.uLeftSeats,
      uRightSeats: uRightSeats ?? this.uRightSeats,
      uBaseSeats: uBaseSeats ?? this.uBaseSeats,
      tableColumns: tableColumns ?? this.tableColumns,
      tableRows: tableRows ?? this.tableRows,
    );
  }
}

/// Etüt salonu kaydı.
///
/// Salon hangi bölüme, bloğa ve kata aitse o bilgiler de saklanır; kapasite
/// oturma düzeninden otomatik hesaplanır.
class StudyRoom {
  const StudyRoom({
    required this.id,
    required this.name,
    required this.section,
    required this.blockName,
    required this.floorLabel,
    required this.floorNumber,
    required this.capacity,
    required this.seating,
    required this.layout,
    required this.occupantCount,
    this.tableSize,
    this.tablesHaveStudents = false,
  });

  final int id;
  final String name;
  final BoardingSection section;
  final String blockName;
  final String floorLabel;
  final int floorNumber;

  /// Düzen ve masa bilgilerinden hesaplanan kapasite.
  final int capacity;

  final StudyRoomSeating seating;
  final StudyRoomLayout layout;

  /// Grup çalışma masası düzeninde masanın kaç kişilik olduğu.
  final int? tableSize;

  /// Grup düzeninde masanın baş ucunda oturan var mı.
  final bool tablesHaveStudents;

  final int occupantCount;

  int get availableCapacity {
    final remaining = capacity - occupantCount;
    return remaining < 0 ? 0 : remaining;
  }

  String get sectionLabel => section.label;

  int get effectiveTableSize => tableSize ?? 4;

  int get seatsPerTable => effectiveTableSize + (tablesHaveStudents ? 2 : 0);

  /// Artı butonlarından sonra yerleşimi değişmiş kopya döndürür.
  StudyRoom copyWithLayout({
    required StudyRoomLayout layout,
    required int capacity,
    int? tableSize,
    bool? tablesHaveStudents,
  }) {
    return StudyRoom(
      id: id,
      name: name,
      section: section,
      blockName: blockName,
      floorLabel: floorLabel,
      floorNumber: floorNumber,
      capacity: capacity,
      seating: seating,
      layout: layout,
      tableSize: tableSize ?? this.tableSize,
      tablesHaveStudents: tablesHaveStudents ?? this.tablesHaveStudents,
      occupantCount: occupantCount,
    );
  }
}

/// Salona yerleştirilmiş öğrenci kaydı.
class StudyRoomAssignment {
  const StudyRoomAssignment({
    required this.studyRoomId,
    required this.studentId,
    this.assignedAt,
  });

  final int studyRoomId;
  final int studentId;
  final DateTime? assignedAt;
}

/// Salon ekleme diyaloğunda seçilebilecek bölüm / blok / kat bilgisi.
class StudyRoomFloorOption {
  const StudyRoomFloorOption({
    required this.section,
    required this.blockName,
    required this.floorLabel,
    required this.floorNumber,
  });

  final BoardingSection section;
  final String blockName;
  final String floorLabel;
  final int floorNumber;

  String get label => '${section.label} • $blockName • $floorLabel';
}

/// Bir katta bulunan, henüz hiçbir etüt salonuna yerleştirilmemiş öğrenciler.
class StudyRoomFloorPool {
  const StudyRoomFloorPool({
    required this.section,
    required this.blockName,
    required this.floorLabel,
    required this.floorNumber,
    required this.studentIds,
  });

  final BoardingSection section;
  final String blockName;
  final String floorLabel;
  final int floorNumber;
  final List<int> studentIds;

  String get label => '${section.label} • $blockName • $floorLabel';
}
