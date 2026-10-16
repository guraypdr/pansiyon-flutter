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
import 'package:pansiyon_yonetim/features/students/data/student_duty_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_form_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/archive_student_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_detail_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_import_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_support_dialogs.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_duty_tab.dart';
import 'package:pansiyon_yonetim/features/students/presentation/students_overview_tab.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.repository,
    this.boardingInfoRepository,
    this.roomRepository,
    this.dutyRepository,
  });

  final StudentRepository repository;
  final BoardingInfoRepository? boardingInfoRepository;
  final RoomRepository? roomRepository;

  /// Öğrenci nöbet listeleri için depo; verilmezse nöbet sekmesi gizlenir.
  final StudentDutyRepository? dutyRepository;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  List<Student> _students = const [];
  List<School> _schools = const [];
  List<String> _classLevels = const [];
  BoardingType? _boardingType;
  String _searchQuery = '';
  String? _schoolName;
  List<BoardingRoom> _rooms = const [];
  List<RoomAssignment> _roomAssignments = const [];
  bool _isLoading = true;
  bool _isPrinting = false;

  /// Arşivlenen (pansiyondan ayrılan) öğrenciler; ayrı modülde listelenir.
  List<Student> _archivedStudents = const [];

  /// Aktif modül: 0 = öğrenci listesi, 1 = nöbetler, 2 = arşiv.
  int _selectedTab = 0;

  /// Süzgeçlerin daralttığı öğrenci sayısı; başlık özeti için saklanır.
  int? _visibleCount;

  bool _hasActiveFilters = false;

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
        widget.repository.getStudents(
          query: _searchQuery,
          includeArchived: true,
        ),
      ]);
      final students = results[0] as List<Student>;
      final schools = results[1] as List<School>;
      final boardingInfo = results[2] as BoardingInfoDraft?;
      final rooms = results[3] as List<BoardingRoom>;
      final assignments = results[4] as List<RoomAssignment>;
      // Arşiv modülü ayrı liste tutar; aktif öğrencilerden arşivlenenler
      // çıkarılır.
      final all = results[5] as List<Student>;
      final archived = all.where((student) => student.isArchived).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _students = students;
        _archivedStudents = archived;
        _schools = schools;
        _rooms = rooms;
        _roomAssignments = assignments;
        _schoolName = boardingInfo?.schoolName;
        _classLevels = classLevelsForEducationLevel(
          boardingInfo?.educationLevel,
          hasPreparationGrade: boardingInfo?.hasPreparationGrade ?? true,
        );
        _boardingType = boardingInfo?.boardingType;
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
    // Diğer çıktı ekranlarıyla aynı davranış: yüklenen öğrenciler basılır.
    return buildContactSheetGroups(
      students: _students,
      roomOf: _roomForStudent,
    );
  }

  Future<void> _printContactSheet() async {
    final groups = _buildContactSheetGroups();
    if (groups.isEmpty) {
      _notify('Yazdırılacak öğrenci yok.', AppNotificationTone.error);
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

  /// Öğrenciyi silmeden pansiyondan ayrılır; ayrılış tarihi ve sebebi sorulur.
  Future<void> _archiveStudent(Student student) async {
    final request = await showDialog<StudentArchiveRequest>(
      context: context,
      builder: (dialogContext) => ArchiveStudentDialog(
        studentName: student.fullName,
        registrationDate: student.boardingRegistrationDate,
      ),
    );
    if (request == null || student.id == null) {
      return;
    }
    try {
      await widget.repository.archiveStudent(
        id: student.id!,
        exitDate: request.exitDate,
        reason: request.resolvedReason,
      );
      await _syncDutyAfterArchive();
      await _refreshStudents();
      _notify('${student.fullName} arşivlendi.', AppNotificationTone.success);
    } catch (_) {
      _notify('Öğrenci arşivlenemedi.', AppNotificationTone.error);
    }
  }

  /// Arşivlenen öğrenciyi nöbet listesinden düşürür ve sonrakileri bir öne
  /// kaydırır. Nöbet deposu verilmemişse hiçbir şey yapılmaz.
  Future<void> _syncDutyAfterArchive() async {
    final dutyRepository = widget.dutyRepository;
    if (dutyRepository == null) {
      return;
    }
    try {
      // Arşivdeki tüm öğrenciler bilinir; liste yalnızca bunlardan arınır.
      final archived = await widget.repository.getStudents(
        includeArchived: true,
      );
      await dutyRepository.removeArchivedStudents({
        for (final item in archived)
          if (item.id != null) item.id!,
      });
    } catch (_) {
      // Nöbet listesi güncellenemezse arşivleme akışı bozulmaz.
    }
  }

  /// Arşivlenen öğrenciyi yeniden pansiyona alır.
  Future<void> _restoreStudent(Student student) async {
    if (student.id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arşivden çıkar'),
        content: Text(
          '${student.fullName} yeniden pansiyona alınsın mı? '
          'Ayrılış bilgileri silinir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Geri Al'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.repository.restoreStudent(student.id!);
      await _refreshStudents();
      _notify(
        '${student.fullName} arşivden çıkarıldı.',
        AppNotificationTone.success,
      );
    } catch (_) {
      _notify('Öğrenci arşivden çıkarılamadı.', AppNotificationTone.error);
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

    return ColoredBox(
      color: AppColors.appBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.pageGutter,
              AppTokens.gapMd,
              AppTokens.pageGutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildTabBar(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildActiveTab()),
        ],
      ),
    );
  }

  /// Modül seçici.
  ///
  /// Nöbet deposu verilmediğinde yalnızca liste ve arşiv modülleri sunulur.
  Widget _buildTabBar() {
    final dutyRepository = widget.dutyRepository;
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            key: const Key('students_tab_overview'),
            label: 'Öğrenci Listesi',
            icon: Icons.people_outline,
            selected: _selectedTab == 0,
            onPressed: () => setState(() => _selectedTab = 0),
          ),
        ),
        const SizedBox(width: 8),
        if (dutyRepository != null) ...[
          Expanded(
            child: _TabButton(
              key: const Key('students_tab_duty'),
              label: 'Nöbetler',
              icon: Icons.event_available_outlined,
              selected: _selectedTab == 1,
              onPressed: () => setState(() => _selectedTab = 1),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: _TabButton(
            key: const Key('students_tab_archive'),
            label: 'Arşiv',
            icon: Icons.inventory_2_outlined,
            selected: _selectedTab == _archiveTabIndex,
            onPressed: () => setState(() => _selectedTab = _archiveTabIndex),
          ),
        ),
      ],
    );
  }

  /// Arşiv modülünün sıra numarası; nöbet deposu olmadığında 1'e düşer.
  int get _archiveTabIndex => widget.dutyRepository == null ? 1 : 2;

  Widget _buildActiveTab() {
    final dutyRepository = widget.dutyRepository;
    if (dutyRepository != null && _selectedTab == 1) {
      return StudentDutyTab(
        repository: dutyRepository,
        students: _students,
        roomOf: _roomForStudent,
        schoolName: _schoolName,
      );
    }
    final isArchive = _selectedTab == _archiveTabIndex;
    return StudentsOverviewTab(
      key: ValueKey<String>(
        isArchive ? 'students_archive_view' : 'students_active_view',
      ),
      students: isArchive ? _archivedStudents : _students,
      classLevels: _classLevels,
      schools: _schools,
      boardingType: _boardingType,
      isArchiveView: isArchive,
      roomOf: _roomForStudent,
      onSearchChanged: (query) {
        _searchQuery = query;
        _refreshStudents();
      },
      onFilterStatsChanged: ({
        required visibleCount,
        required totalCount,
        required hasActiveFilters,
      }) {
        // Süzgeç durumu liste modülünde tutulur; başlık özeti burada güncellenir.
        if (!mounted) return;
        setState(() {
          _visibleCount = visibleCount;
          _hasActiveFilters = hasActiveFilters;
        });
      },
      onOpenDetail: _openStudentDetail,
      onEdit: _openStudentForm,
      onDelete: _deleteStudent,
      onArchive: isArchive ? _restoreStudent : _archiveStudent,
    );
  }

  String get _summaryLine {
    final isArchive = _selectedTab == _archiveTabIndex;
    final total = isArchive ? _archivedStudents.length : _students.length;
    if (_hasActiveFilters && _visibleCount != null) {
      return '$_visibleCount / $total öğrenci gösteriliyor';
    }
    if (total == 0) {
      return isArchive ? 'Arşivde öğrenci yok' : 'Henüz öğrenci yok';
    }
    return isArchive
        ? '$total arşivlenmiş öğrenci'
        : '$total öğrenci kayıtlı';
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ).createShader(bounds),
                child: const Text(
                  'Öğrenciler',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
              ),
              if (_schoolName != null && _schoolName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  _schoolName!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _summaryLine,
                style: AppTypography.caption.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppMenuButton<_HeaderMenuAction>(
              key: const Key('students_header_menu'),
              label: 'İşlemler',
              icon: Icons.more_horiz,
              isLoading: _isPrinting,
              onSelected: (action) => _runHeaderAction(action),
              items: const [
                PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.importExcel,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.upload_file, size: 20),
                    title: Text('Toplu Yükle (Excel)'),
                  ),
                ),
                PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.downloadTemplate,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.download_outlined, size: 20),
                    title: Text('Şablon İndir'),
                  ),
                ),
                PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.schoolSettings,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.school_outlined, size: 20),
                    title: Text('Okul Ayarları'),
                  ),
                ),
                PopupMenuItem<_HeaderMenuAction>(
                  value: _HeaderMenuAction.print,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.print_outlined, size: 20),
                    title: Text('Yazdır'),
                  ),
                ),
              ],
            ),
            AppPrimaryButton(
              key: const Key('add_student_button'),
              label: 'Öğrenci Ekle',
              icon: Icons.person_add_alt_1,
              onPressed: _openStudentForm,
            ),
          ],
        ),
      ],
    );
  }

  /// Başlık menüsünden seçilen eylemi çalıştırır.
  Future<void> _runHeaderAction(_HeaderMenuAction action) async {
    switch (action) {
      case _HeaderMenuAction.importExcel:
        await _importFromExcel();
      case _HeaderMenuAction.downloadTemplate:
        await _downloadTemplate();
      case _HeaderMenuAction.schoolSettings:
        await _openSchoolSettings();
      case _HeaderMenuAction.print:
        await _printContactSheet();
    }
  }
}

/// Başlık menüsündeki eylemler.
///
/// Sağ üstteki ikincil işlemler (Excel yükleme, şablon indirme, okul
/// ayarları, yazdırma) tek bir açılır menüde toplanır.
enum _HeaderMenuAction {
  importExcel,
  downloadTemplate,
  schoolSettings,
  print,
}

/// Öğrenciler sayfasının modül seçici düğmesi.
class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.10)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.inputBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.secondaryText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
