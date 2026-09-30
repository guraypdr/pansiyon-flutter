import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/study_rooms/domain/study_room_models.dart';
import 'package:pansiyon_yonetim/features/study_rooms/presentation/study_room_seating_preview.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

/// Yazdırılacak tek bir etüt salonu ve içindeki öğrenciler.
class StudyRoomLayoutEntry {
  const StudyRoomLayoutEntry({required this.room, required this.students});

  final StudyRoom room;
  final List<Student> students;
}

const _planBorderColor = PdfColor.fromInt(0xFF9AA0A6);
const _occupiedFill = PdfColor.fromInt(0xFFE8F0FE);
const _emptyFill = PdfColor.fromInt(0xFFF5F5F7);
const _pageMargin = 20.0;
const _seatNameFontSize = 7.2;
const _numberWidth = 40.0;
const _nameWidth = 420.0;
const _classWidth = 342.0;

/// Yatay A4 sayfası; yerleşim planı sayfayı tamamen kullanır.
final PdfPageFormat _pageFormat = PdfPageFormat.a4.landscape;

double get _contentWidth => _pageFormat.width - _pageMargin * 2;

/// Etüt salonu yerleşim planlarını yazdırır.
///
/// Her salon için iki sayfa üretilir: birincisi oturma düzeninin tam sayfa
/// çizimi, ikincisi ise numaralı öğrenci listesi.
Future<void> printStudyRoomLayouts({
  required String schoolName,
  required List<StudyRoomLayoutEntry> entries,
}) async {
  if (entries.isEmpty) {
    return;
  }
  final bytes = await buildStudyRoomLayoutsPdf(
    schoolName: schoolName,
    entries: entries,
  );
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: 'Etüt Salonu Yerleşim Planı - $schoolName',
  );
}

/// Yerleşim planı çıktısının PDF verisini üretir.
Future<Uint8List> buildStudyRoomLayoutsPdf({
  required String schoolName,
  required List<StudyRoomLayoutEntry> entries,
}) async {
  if (entries.isEmpty) {
    return Uint8List(0);
  }
  final fonts = await ReportFonts.load();
  final document = pw.Document(
    title: 'Etüt Salonu Yerleşim Planı',
    author: schoolName,
  );
  final today = DateTime.now();

  for (final entry in entries) {
    final plan = SeatPlan.of(
      seating: entry.room.seating,
      layout: entry.room.layout,
      tableSize: entry.room.tableSize ?? 4,
      tablesHaveStudents: entry.room.tablesHaveStudents,
      studentCount: entry.students.length,
    );
    final header = buildReportHeader(
      fonts: fonts,
      educationYear: reportEducationYear(today),
      schoolName: schoolName,
      reportTitle: 'Etüt Salonu Yerleşim Planı',
      locationLabel:
          '${entry.room.sectionLabel} • ${entry.room.blockName} • '
          '${entry.room.floorLabel}',
      date: today,
    );

    // 1. sayfa: oturma düzeni sayfayı tamamen kaplar.
    final infoHeight = 18.0;
    final availableHeight =
        _pageFormat.height - _pageMargin * 2 - 96 - infoHeight - 10;
    document.addPage(
      pw.Page(
        pageFormat: _pageFormat,
        margin: const pw.EdgeInsets.all(_pageMargin),
        build: (context) => pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  header,
                  _buildRoomInfo(entry: entry, fonts: fonts),
                  pw.SizedBox(height: 10),
                  pw.Expanded(
                    child: pw.Center(
                      child: _buildPlan(
                        entry: entry,
                        plan: plan,
                        fonts: fonts,
                        maxWidth: _contentWidth,
                        maxHeight: math.max(120, availableHeight),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _pageFooter(context),
          ],
        ),
      ),
    );

    // 2. sayfa: numaralı öğrenci listesi.
    document.addPage(
      pw.Page(
        pageFormat: _pageFormat,
        margin: const pw.EdgeInsets.all(_pageMargin),
        build: (context) => pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  header,
                  _buildRoster(entry: entry, fonts: fonts),
                ],
              ),
            ),
            _pageFooter(context),
          ],
        ),
      ),
    );
  }

  return document.save();
}

pw.Widget _pageFooter(pw.Context context) {
  return pw.Positioned(
    right: 0,
    bottom: 0,
    child: pw.Text(
      'Sayfa ${context.pageNumber} / ${context.pagesCount}',
      style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
    ),
  );
}

pw.Widget _buildRoomInfo({
  required StudyRoomLayoutEntry entry,
  required ReportFonts fonts,
}) {
  final room = entry.room;
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        room.name,
        style: fonts.style(11, bold: true).copyWith(color: PdfColors.black),
      ),
      pw.Text(
        '${entry.students.length} / ${room.capacity} kişi • ${room.seating.label}'
        '${room.tableSize != null ? ' • ${room.tableSize} kişilik masa' : ''}',
        style: fonts.style(8.5).copyWith(color: PdfColors.grey700),
      ),
    ],
  );
}

/// Salonun oturma düzenini verilen alana sığacak şekilde ölçekli çizer.
pw.Widget _buildPlan({
  required StudyRoomLayoutEntry entry,
  required SeatPlan plan,
  required ReportFonts fonts,
  required double maxWidth,
  required double maxHeight,
}) {
  final canvas = plan.canvasSize;
  if (canvas.width <= 0 || canvas.height <= 0) {
    return pw.SizedBox();
  }
  final scale = math.min(maxWidth / canvas.width, maxHeight / canvas.height);
  final planWidth = canvas.width * scale;
  final planHeight = canvas.height * scale;
  // Yazı boyutu da ölçekle birlikte büyür; tahta kadar okunur kalır.
  final fontScale = scale.clamp(1.0, 2.2);

  return pw.Container(
    width: planWidth,
    height: planHeight,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _planBorderColor, width: 0.8),
    ),
    child: pw.Stack(
      children: [
        if (plan.board != null)
          pw.Positioned(
            left: plan.board!.left * scale,
            top: plan.board!.top * scale,
            child: pw.SizedBox(
              width: plan.board!.width * scale,
              height: math.max(3, plan.board!.height * scale),
              child: pw.Container(
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF3A3A3A),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Text(
                  'TAHTA',
                  style: fonts
                      .style(5.5 * fontScale, bold: true)
                      .copyWith(color: PdfColors.white),
                ),
              ),
            ),
          ),
        for (var index = 0; index < plan.cells.length; index++)
          _buildSeat(
            fonts: fonts,
            scale: scale,
            fontScale: fontScale,
            cell: plan.cells[index],
            students: entry.students,
          ),
        for (final table in plan.tables)
          pw.Positioned(
            left: table.left * scale,
            top: table.top * scale,
            child: pw.SizedBox(
              width: table.width * scale,
              height: table.height * scale,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _planBorderColor, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(3),
                  color: _emptyFill,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

pw.Widget _buildSeat({
  required ReportFonts fonts,
  required double scale,
  required double fontScale,
  required SeatCell cell,
  required List<Student> students,
}) {
  final names = <String>[
    for (final seat in cell.seatIndexes)
      seat < students.length ? students[seat].fullName : '',
  ];
  final isFilled = names.any((name) => name.trim().isNotEmpty);
  final seatLabel = cell.isPair
      ? (cell.seatIndexes.length > 1
            ? '${cell.seatIndexes.first + 1}-${cell.seatIndexes.last + 1}'
            : '${cell.seatIndexes.first + 1}')
      : '${cell.seatIndexes.first + 1}';

  return pw.Positioned(
    left: cell.rect.left * scale,
    top: cell.rect.top * scale,
    child: pw.SizedBox(
      width: cell.rect.width * scale,
      height: cell.rect.height * scale,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 1),
        decoration: pw.BoxDecoration(
          color: isFilled ? _occupiedFill : _emptyFill,
          border: pw.Border.all(color: _planBorderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: math.max(9, 13 * fontScale),
              alignment: pw.Alignment.center,
              child: pw.Text(
                seatLabel,
                style: fonts
                    .style(6 * fontScale)
                    .copyWith(color: PdfColors.grey700),
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  for (final name in names)
                    pw.Text(
                      reportTruncate(name, cell.isPair ? 20 : 12),
                      maxLines: 1,
                      style: fonts
                          .style(_seatNameFontSize * fontScale)
                          .copyWith(color: reportTextColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

pw.Widget _buildRoster({
  required StudyRoomLayoutEntry entry,
  required ReportFonts fonts,
}) {
  if (entry.students.isEmpty) {
    return pw.Text(
      'Bu salona yerleştirilmiş öğrenci yok.',
      style: fonts.style(8.5).copyWith(color: PdfColors.grey700),
    );
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        children: [
          reportHeadCell(
            text: '#',
            fonts: fonts,
            height: reportCellHeight,
            width: _numberWidth,
            alignment: pw.Alignment.center,
          ),
          reportHeadCell(
            text: 'Öğrenci',
            fonts: fonts,
            height: reportCellHeight,
            width: _nameWidth,
            alignment: pw.Alignment.centerLeft,
          ),
          reportHeadCell(
            text: 'Sınıf / Şube',
            fonts: fonts,
            height: reportCellHeight,
            width: _classWidth,
            alignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
      for (var index = 0; index < entry.students.length; index++)
        pw.Row(
          children: [
            reportCell(
              text: '${index + 1}',
              fonts: fonts,
              height: reportRowHeight,
              width: _numberWidth,
              alignment: pw.Alignment.center,
            ),
            reportCell(
              text: entry.students[index].fullName,
              fonts: fonts,
              height: reportRowHeight,
              width: _nameWidth,
            ),
            reportCell(
              text: formatClassSectionLabel(
                entry.students[index].className,
                entry.students[index].sectionName,
              ),
              fonts: fonts,
              height: reportRowHeight,
              width: _classWidth,
            ),
          ],
        ),
    ],
  );
}
