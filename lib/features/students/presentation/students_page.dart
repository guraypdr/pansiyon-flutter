import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pansiyon_yonetim/core/files/save_file_helper.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/validation/user_error_message.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/data/contact_sheet_pdf.dart';
import 'package:pansiyon_yonetim/features/students/data/student_excel_importer.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_completeness.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_form_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_detail_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_import_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_list_row.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_support_dialogs.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_page_header.dart';
import 'package:pansiyon_yonetim/shared/widgets/student_gender_figure.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.repository,
    this.boardingInfoRepository,
    this.roomRepository,
  });

  final StudentRepository repository;
  final BoardingInfoRepository? boardingInfoRepository;
  final RoomRepository? roomRepository;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  List<Student> _students = const [];
  List<School> _schools = const [];
  List<String> _classLevels = const [];
  BoardingType? _boardingType;
  String _searchQuery = '';
  String? _classFilter;
  int? _schoolFilter;
  StudentGender? _genderFilter;
  List<BoardingRoom> _rooms = const [];
  List<RoomAssignment> _roomAssignments = const [];
  bool _isLoading = true;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final boardingInfoFuture =
          widget.boardingInfoRepository?.load() ??
          Future<BoardingInfoDraft?>.value(null);
      final roomsFuture =
          widget.roomRepository?.getRooms() ??
          Future<List<BoardingRoom>>.value(const []);
      final assignmentsFuture =
          widget.roomRepository?.getAssignments() ??
          Future<List<RoomAssignment>>.value(const []);
      // Okul/şube verisi hata verse bile öğrenci listesi boş kalmaz.
      final schoolsFuture = _loadSchoolsSafely();
      final results = await Future.wait<Object?>([
        widget.repository.getStudents(query: _searchQuery),
        schoolsFuture,
        boardingInfoFuture,
        roomsFuture,
        assignmentsFuture,
      ]);
      final students = results[0] as List<Student>;
      final schools = results[1] as List<School>;
      final boardingInfo = results[2] as BoardingInfoDraft?;
      final rooms = results[3] as List<BoardingRoom>;
      final assignments = results[4] as List<RoomAssignment>;
      if (!mounted) {
        return;
      }
      setState(() {
        _students = students;
        _schools = schools;
        _rooms = rooms;
        _roomAssignments = assignments;
        _classLevels = classLevelsForEducationLevel(
          boardingInfo?.educationLevel,
          hasPreparationGrade: boardingInfo?.hasPreparationGrade ?? true,
        );
        _boardingType = boardingInfo?.boardingType;
        _classFilter = _classLevels.contains(_classFilter)
            ? _classFilter
            : null;
        _schoolFilter = _schools.any((school) => school.id == _schoolFilter)
            ? _schoolFilter
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _notify('Öğrenci bilgileri yüklenemedi.', AppNotificationTone.error);
    }
  }

  /// Okul ve şube bilgisi hata verirse liste boşalmaz.
  Future<List<School>> _loadSchoolsSafely() async {
    try {
      return await widget.repository.getSchools();
    } catch (_) {
      return const [];
    }
  }

  BoardingRoom? _roomForStudent(int studentId) {
    for (final assignment in _roomAssignments) {
      if (assignment.studentId == studentId) {
        for (final room in _rooms) {
          if (room.id == assignment.roomId) {
            return room;
          }
        }
      }
    }
    return null;
  }

  List<ContactSheetGroup> _buildContactSheetGroups() {
    // Diğer çıktı ekranlarıyla aynı davranış: ekranda görünen öğrenciler
    // basılır. Sınıf/okul/cinsiyet süzgeçleri etkin olduğunda çıktı da
    // süzülmüş olur.
    return buildContactSheetGroups(
      students: _visibleStudents,
      roomOf: _roomForStudent,
    );
  }

  Future<void> _printContactSheet() async {
    final groups = _buildContactSheetGroups();
    if (groups.isEmpty) {
      _notify(
        _hasActiveFilters
            ? 'Yazdırılacak öğrenci yok. Sınıf, okul ve cinsiyet seçimini '
                  'gözden geçirin.'
            : 'Yazdırılacak öğrenci yok.',
        AppNotificationTone.error,
      );
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final boardingInfo = await widget.boardingInfoRepository?.load();
      final data = ContactSheetData(
        schoolName: boardingInfo?.schoolName ?? '',
        educationYear: reportEducationYear(DateTime.now()),
        date: DateTime.now(),
        groups: groups,
      );
      final fonts = await ReportFonts.load();
      final bytes = await buildContactSheetPdf(
        pw.Document(),
        data,
        fonts,
      ).save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Öğrenci İletişim Bilgileri Formu',
      );
    } catch (_) {
      _notify('Yazdırma hazırlanamadı.', AppNotificationTone.error);
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _refreshStudents() async {
    setState(() => _isLoading = true);
    await _load();
  }

  Future<void> _openStudentForm([Student? student]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StudentFormDialog(
          repository: widget.repository,
          schools: _schools,
          student: student,
          classLevels: _classLevels,
          boardingType: _boardingType,
          boardingInfoRepository: widget.boardingInfoRepository,
        );
      },
    );
    if (saved == true) {
      await _refreshStudents();
      _notify(
        student == null ? 'Öğrenci eklendi.' : 'Öğrenci güncellendi.',
        AppNotificationTone.success,
      );
    }
  }

  Future<void> _importFromExcel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    final filePath = result.isEmpty ? null : result.single.path;
    if (filePath == null || !mounted) {
      return;
    }

    try {
      final preview = await const StudentExcelImporter().readFile(filePath);
      if (!mounted) {
        return;
      }
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StudentImportDialog(preview: preview),
      );
      if (shouldImport != true || !mounted) {
        return;
      }

      final schools = [..._schools];
      final students = <Student>[];
      // Excel'de dolu olan hücreler kaydedilir; boş bırakılan alanlar
      // güncellemede mevcut değerini korur. Liste `students` ile aynı
      // sırada tutulur.
      final filledFieldsByIndex = <int, Set<String>>{};
      var correctedGenderCount = 0;
      for (final row in preview.rows) {
        // Ad Soyad ve T.C. Kimlik No zorunludur; eksik satırlar atlanır.
        if (row.missingFields.contains('Ad Soyad') ||
            row.missingFields.contains('T.C. Kimlik No')) {
          continue;
        }
        var schoolId = row.student.schoolId;
        final schoolName = row.schoolName?.trim();
        final hasSchoolName = schoolName != null && schoolName.isNotEmpty;
        if (hasSchoolName) {
          School? school;
          for (final item in schools) {
            if (item.name.toLowerCase() == schoolName.toLowerCase()) {
              school = item;
              break;
            }
          }
          school ??= School(
            id: await widget.repository.saveSchool(School(name: schoolName)),
            name: schoolName,
          );
          schools.add(school);
          schoolId = school.id;
        }
        // Tek cinsiyetli pansiyonda cinsiyet kilitlidir, dosyadaki değer
        // pansiyon türüne göre düzeltilir.
        final (constrained, wasCorrected) = applyBoardingGenderConstraint(
          row.student,
          _boardingType,
        );
        if (wasCorrected) {
          correctedGenderCount++;
        }
        final filled = <String>{...row.filledFieldKeys};
        if (hasSchoolName) {
          filled.add('school_id');
        }
        filledFieldsByIndex[students.length] = filled;
        students.add(constrained.withSchoolId(schoolId));
      }
      final result = await widget.repository.importStudents(
        students,
        filledFieldsByIndex: filledFieldsByIndex,
      );
      await _refreshStudents();
      final correctionNote = correctedGenderCount == 0
          ? ''
          : ' $correctedGenderCount öğrencinin cinsiyeti pansiyon türüne '
                'göre düzeltildi.';
      final skippedNote = preview.skippedCount == 0
          ? ''
          : ' ${preview.skippedCount} satır atlandı (ad veya T.C. kimlik '
                'numarası eksik).';
      _notify(
        '${result.total} öğrenci işlendi. '
        '${result.added} öğrenci eklendi, ${result.updated} öğrenci '
        'güncellendi.$correctionNote$skippedNote',
        AppNotificationTone.success,
      );
    } on StudentDataIntegrityException catch (error) {
      _notify(error.message, AppNotificationTone.error);
    } on FormatException catch (error) {
      await _logImportFailure(filePath, error);
      _notify(
        '${error.message}\n\nDosya: ${_fileName(filePath)}',
        AppNotificationTone.error,
      );
    } catch (error) {
      await _logImportFailure(filePath, error);
      _notify(
        '${userErrorMessage(error, fallback: 'Excel dosyası okunamadı.')}'
        '\n\nDosya: ${_fileName(filePath)}',
        AppNotificationTone.error,
      );
    }
  }

  static String _fileName(String filePath) {
    final parts = filePath.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? filePath : parts.last;
  }

  /// İçe aktarma hatasını günlüğe yazar.
  ///
  /// Arayüzdeki mesaj dosyanın adını da içerir; ancak kullanıcı hâlâ
  /// hangi dosyada sorun olduğunu belirtmezse günlük tek bakışta cevap
  /// verir. Günlük son 20 kaydı tutar.
  static Future<void> _logImportFailure(String filePath, Object error) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final logFile = File(
        '${directory.path}${Platform.pathSeparator}ice_aktarma_hatalari.log',
      );
      final previous = await logFile.exists()
          ? await logFile.readAsString()
          : '';
      final lines = previous
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      lines.add(
        '${DateTime.now().toIso8601String()} | $filePath | '
        '${error.runtimeType} | $error',
      );
      final trimmed = lines.length > 20
          ? lines.sublist(lines.length - 20)
          : lines;
      await logFile.writeAsString('${trimmed.join('\n')}\n');
    } catch (_) {
      // Günlük yazılamazsa içe aktarma akışı bozulmamalı.
    }
  }

  Future<void> _downloadTemplate() async {
    final bytes = const StudentExcelImporter().createTemplateBytes();
    try {
      final savedPath = await saveBytesWithDialog(
        dialogTitle: 'Excel şablonunu kaydet',
        fileName: 'pansiyon_ogrenci_sablonu.xlsx',
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted || savedPath == null) {
        return;
      }
      _notify(
        'Excel şablonu kaydedildi: $savedPath',
        AppNotificationTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      // Diyalog kullanıcıyı kilitlediyse veya yazma başarısız olduysa,
      // şablonu yazılabilir olduğu bilinen klasöre kaydedip yolunu
      // bildiriyoruz; aksi hâlde kullanıcı eline hiçbir şey geçmiyor.
      final fallback = await _saveTemplateToFallback(bytes);
      if (fallback != null) {
        _notify(
          'Şablon masaüstü diyaloğu kullanılamadı, şu konuma kaydedildi: '
          '$fallback',
          AppNotificationTone.success,
        );
        return;
      }
      _notify(
        userErrorMessage(error, fallback: 'Excel şablonu oluşturulamadı.'),
        AppNotificationTone.error,
      );
    }
  }

  /// Diyalog başarısız olduğunda şablonu İndirilenler klasörüne yazar.
  Future<String?> _saveTemplateToFallback(List<int> bytes) async {
    try {
      final directory = await resolveSaveDirectory();
      if (directory == null) {
        return null;
      }
      final file = File(
        '$directory${Platform.pathSeparator}'
        'pansiyon_ogrenci_sablonu.xlsx',
      );
      await writeFileChecked(file.path, bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSchoolSettings() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return SchoolSettingsDialog(
          repository: widget.repository,
          boardingInfoRepository: widget.boardingInfoRepository,
        );
      },
    );
    if (changed == true) {
      await _refreshStudents();
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Öğrenciyi sil'),
          content: Text('${student.fullName} silinsin mi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true || student.id == null) {
      return;
    }
    try {
      await widget.repository.deleteStudent(student.id!);
      await _refreshStudents();
      _notify('Öğrenci silindi.', AppNotificationTone.success);
    } catch (_) {
      _notify('Öğrenci silinemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _openStudentDetail(Student student) async {
    if (student.id == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StudentDetailDialog(
        repository: widget.repository,
        studentId: student.id!,
        schools: _schools,
        classLevels: _classLevels,
        boardingType: _boardingType,
        boardingInfoRepository: widget.boardingInfoRepository,
      ),
    );
    await _refreshStudents();
  }

  /// Araç çubuğundaki filtrelere göre süzülmüş öğrenci listesi.
  List<Student> get _visibleStudents {
    return _students
        .where((student) {
          if (_classFilter != null && student.className != _classFilter) {
            return false;
          }
          if (_schoolFilter != null && student.schoolId != _schoolFilter) {
            return false;
          }
          if (_genderFilter != null && student.gender != _genderFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  bool get _hasActiveFilters =>
      _classFilter != null || _schoolFilter != null || _genderFilter != null;

  void _clearFilters() {
    setState(() {
      _classFilter = null;
      _schoolFilter = null;
      _genderFilter = null;
    });
  }

  void _notify(String message, AppNotificationTone tone) {
    if (!mounted) {
      return;
    }
    AppNotifier.instance.show(context, message: message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = _visibleStudents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: 'Öğrenciler',
          subtitle: _summaryLine,
          actions: [
            AppIconAction(
              key: const Key('import_students_button'),
              icon: Icons.upload_file,
              tooltip: 'Toplu Yükle (Excel)',
              onPressed: _importFromExcel,
            ),
            AppIconAction(
              key: const Key('download_template_button'),
              icon: Icons.download_outlined,
              tooltip: 'Şablon İndir',
              onPressed: _downloadTemplate,
            ),
            AppIconAction(
              key: const Key('school_settings_button'),
              icon: Icons.school_outlined,
              tooltip: 'Okul Ayarları',
              onPressed: _openSchoolSettings,
            ),
            AppIconAction(
              key: const Key('students_print_button'),
              icon: Icons.print_outlined,
              tooltip: 'Yazdır',
              isLoading: _isPrinting,
              onPressed: _isPrinting
                  ? null
                  : () => unawaited(_printContactSheet()),
            ),
            AppPrimaryButton(
              key: const Key('add_student_button'),
              label: 'Öğrenci Ekle',
              icon: Icons.person_add_alt_1,
              onPressed: _openStudentForm,
            ),
          ],
          bottom: _buildFilters(),
        ),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(
                  icon: Icons.people_outline,
                  title: _students.isEmpty
                      ? 'Henüz öğrenci eklenmemiş'
                      : 'Filtrelere uyan öğrenci yok',
                  message: _students.isEmpty
                      ? 'İlk öğrenciyi ekleyerek pansiyon kayıtlarını oluşturun.'
                      : 'Filtreleri temizleyerek tüm öğrencileri görebilirsiniz.',
                )
              : _StudentList(
                  students: visible,
                  roomOf: _roomForStudent,
                  onOpenDetail: _openStudentDetail,
                  onEdit: _openStudentForm,
                  onDelete: _deleteStudent,
                ),
        ),
      ],
    );
  }

  String get _summaryLine {
    final total = _students.length;
    final visible = _visibleStudents.length;
    if (_hasActiveFilters) {
      return '$visible / $total öğrenci gösteriliyor';
    }
    return total == 0 ? 'Henüz öğrenci yok' : '$total öğrenci kayıtlı';
  }

  Widget _buildFilters() {
    final searchField = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 340),
      child: TextField(
        key: const Key('student_search_field'),
        onChanged: (value) => _searchQuery = value,
        onSubmitted: (_) => _refreshStudents(),
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Öğrenci ara',
          prefixIcon: Icon(Icons.search, size: 20),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final filters = <Widget>[
          _FilterButton<String>(
            filterKey: const Key('class_filter_button'),
            label: 'Sınıf',
            value: _classFilter,
            hint: 'Tümü',
            options: _classLevels,
            onSelected: (value) => setState(() => _classFilter = value),
          ),
          _FilterButton<int>(
            filterKey: const Key('school_filter_button'),
            label: 'Okul',
            value: _schoolFilter,
            hint: 'Tümü',
            options: [
              for (final school in _schools)
                if (school.id != null) school.id!,
            ],
            optionLabel: (schoolId) => _schoolLabel(schoolId),
            onSelected: (value) => setState(() => _schoolFilter = value),
          ),
          _FilterButton<StudentGender>(
            filterKey: const Key('gender_filter_button'),
            label: 'Cinsiyet',
            value: _genderFilter,
            hint: 'Tümü',
            options: allowedGendersForBoardingType(_boardingType),
            optionLabel: (gender) => gender.label,
            onSelected: (value) => setState(() => _genderFilter = value),
          ),
          if (_hasActiveFilters)
            TextButton.icon(
              key: const Key('clear_filters_button'),
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Temizle'),
            ),
          searchField,
        ];

        // Geniş ekranda filtreler ve arama tek satırda; dar ekranda sarma
        // kullanılır. Her iki durumda da arama en sağda yer alır.
        if (constraints.maxWidth < 980) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: filters,
          );
        }

        return Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < filters.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      filters[index],
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _schoolLabel(int schoolId) {
    for (final school in _schools) {
      if (school.id == schoolId) {
        return school.name;
      }
    }
    return 'Tümü';
  }
}

/// Öğrencileri kart listesi olarak gösterir.
///
/// Odaya göre gruplama Odalar sayfasının işidir; bu ekran kayıt listesi ve
/// arama içindir.
class _StudentList extends StatelessWidget {
  const _StudentList({
    required this.students,
    required this.roomOf,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Student> students;
  final BoardingRoom? Function(int studentId) roomOf;
  final void Function(Student student) onOpenDetail;
  final void Function(Student student) onEdit;
  final void Function(Student student) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('student_list'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: students.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final student = students[index];
        return _StudentCard(
          student: student,
          room: student.id == null ? null : roomOf(student.id!),
          onOpenDetail: () => onOpenDetail(student),
          onEdit: () => onEdit(student),
          onDelete: () => onDelete(student),
        );
      },
    );
  }
}
/// Tek öğrenci kartı.
///
/// Nöbetler > Öğretmenler kartıyla aynı düzeni kullanır: solda figür, ortada
/// ad ve bilgi rozetleri, sağda eylem düğmeleri. Farkı, yapılandırılmış
/// bilgilerin (sınıf, oda) düz metin yerine rozet olarak gösterilmesidir;
/// nokta ile ayrılmış tek satırdan okumaktan hızlı bulunur.
///
/// Tüm genişlikler sabit + esnek olarak dağıtılır, bu yüzden uzun ad, okul
/// adı veya veli bilgisi taşma üretmez.
class _StudentCard extends StatefulWidget {
  const _StudentCard({
    required this.student,
    required this.room,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final Student student;
  final BoardingRoom? room;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final missing = studentMissingFields(student);
    final classLabel = formatClassSectionLabel(
      student.className,
      student.sectionName,
    );
    final roomLabel = widget.room?.roomNumber.toString();

    // Rozetlerin ardına sığan kalan alan; okul ve veli bilgisi buraya girer.
    final trailingInfo = [
      if (student.schoolName != null) student.schoolName!,
      if (student.guardianPhone != null) 'Veli: ${student.guardianPhone}',
    ].join(' • ');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onOpenDetail,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          key: Key('student_card_${student.id}'),
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.surface
                : AppColors.cardSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.inputBorder,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              StudentGenderFigure(gender: student.gender, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            student.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.darkText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (missing.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _MetaChip(
                            label: '${missing.length} eksik',
                            icon: Icons.warning_amber_rounded,
                            color: missing.any((f) => f.isCritical)
                                ? AppColors.errorFeedback
                                : const Color(0xFFB26A00),
                            tooltip: studentMissingSummary(missing),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (classLabel.isNotEmpty) ...[
                          _MetaChip(label: classLabel, icon: Icons.class_outlined),
                          const SizedBox(width: 6),
                        ],
                        if (roomLabel != null) ...[
                          RoomNumberBadge(label: roomLabel),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            trailingInfo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StudentCardActions(
                studentId: student.id,
                visible: _isHovered,
                onOpenDetail: widget.onOpenDetail,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartın sağındaki detay / düzenleme / sil düğmeleri.
///
/// Üzerine gelmede görünür olur; yalnızca yer kaplar, bu yüzden ad ile
/// rozetlerin genişliği üzerine gelince değişmez.
class _StudentCardActions extends StatelessWidget {
  const _StudentCardActions({
    required this.studentId,
    required this.visible,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final int? studentId;
  final bool visible;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 140),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StudentCardAction(
            actionKey: Key('student_detail_$studentId'),
            tooltip: 'Detay',
            icon: Icons.visibility_outlined,
            onPressed: onOpenDetail,
          ),
          _StudentCardAction(
            actionKey: Key('student_edit_$studentId'),
            tooltip: 'Düzenle',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          _StudentCardAction(
            actionKey: Key('student_delete_$studentId'),
            tooltip: 'Sil',
            icon: Icons.delete_outline,
            color: AppColors.errorFeedback,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _StudentCardAction extends StatelessWidget {
  const _StudentCardAction({
    required this.actionKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final Key actionKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: actionKey,
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20, color: color ?? AppColors.secondaryText),
    );
  }
}

/// Küçük bilgi rozeti (ikon + metin, yuvarlak köşeli).
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.icon,
    this.color,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.secondary;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    final message = tooltip;
    return message == null ? chip : Tooltip(message: message, child: chip);
  }
}

class _FilterButton<T> extends StatelessWidget {
  const _FilterButton({
    required this.filterKey,
    required this.label,
    required this.value,
    required this.hint,
    required this.options,
    required this.onSelected,
    this.optionLabel,
  });

  final Key filterKey;
  final String label;
  final T? value;
  final String hint;
  final List<T> options;
  final ValueChanged<T?> onSelected;
  final String Function(T value)? optionLabel;

  String _text(T option) => optionLabel?.call(option) ?? option.toString();

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    // "Tümü" seçeneği null değer döndürdüğü için menüde sıra numarası
    // taşınır; aksi halde PopupMenuButton seçimi iptal sayar.
    return PopupMenuButton<int>(
      key: filterKey,
      tooltip: '$label filtresi',
      onSelected: (index) => onSelected(index == 0 ? null : options[index - 1]),
      offset: const Offset(0, 44),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.inputBorder),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<int>(value: 0, child: Text('$label: $hint')),
        for (var index = 0; index < options.length; index++)
          PopupMenuItem<int>(
            value: index + 1,
            child: Text(_text(options[index])),
          ),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.inputBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value == null ? label : '$label: ${_text(value as T)}',
              style: TextStyle(
                color: isActive ? AppColors.primaryDark : AppColors.darkText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
