import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/study_rooms/domain/study_room_models.dart';

/// Etüt salonunun canlı oturma planı.
///
/// Sandalyeler, seçilen düzenin sayaçlarına göre sabit boyutta çizilir:
/// tekli/çiftli sıralarda yana ve arkaya sıra, köşeli U düzeninde bacak ve
/// taban, grup düzeninde yatay ve dikey masa sayısı. Salona yerleştirilmiş
/// öğrenciler bu sandalyelere yazılır; sığmayan öğrenci sayısı bildirilir.
/// Etüt salonunun canlı oturma planı.
///
/// Sandalyeler, seçilen düzenin sayaçlarına göre sabit boyutta çizilir:
/// tekli/çiftli sıralarda yana ve arkaya sıra, köşeli U düzeninde bacak ve
/// taban, grup düzeninde yatay ve dikey masa. Salona yerleştirilmiş öğrenciler
/// bu sandalyelere yazılır; plan sığmazsa iki yönde de kaydırılır.
class StudyRoomSeatingMap extends StatefulWidget {
  const StudyRoomSeatingMap({
    super.key,
    required this.seating,
    required this.students,
    required this.layout,
    this.tableSize = 4,
    this.tablesHaveStudents = false,
    this.height = 240,
  });

  final StudyRoomSeating seating;
  final List<Student> students;
  final StudyRoomLayout layout;
  final int tableSize;
  final bool tablesHaveStudents;

  /// Görüntü alanının sabit yüksekliği.
  final double height;

  @override
  State<StudyRoomSeatingMap> createState() => _StudyRoomSeatingMapState();
}

class _StudyRoomSeatingMapState extends State<StudyRoomSeatingMap> {
  final _horizontalController = ScrollController();
  final _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = SeatPlan.of(
      seating: widget.seating,
      layout: widget.layout,
      tableSize: widget.tableSize,
      tablesHaveStudents: widget.tablesHaveStudents,
      studentCount: widget.students.length,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final planWidth = math.max(plan.canvasSize.width, viewportWidth);
        final planHeight = math.max(plan.canvasSize.height, widget.height);
        final scrollableX = plan.canvasSize.width > viewportWidth;
        final scrollableY = plan.canvasSize.height > widget.height;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder),
              ),
              padding: const EdgeInsets.all(10),
              // Görüntü alanı sabit yükseklikte tutulur; plan taşarsa kaydırılır.
              child: SizedBox(
                height: widget.height,
                // Fare tekerleği yatayda da planı kaydırır.
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is! PointerScrollEvent || !scrollableX) {
                      return;
                    }
                    if (!_horizontalController.hasClients) {
                      return;
                    }
                    final delta = event.scrollDelta.dx != 0
                        ? event.scrollDelta.dx
                        : event.scrollDelta.dy;
                    final position = _horizontalController.position;
                    final target = (_horizontalController.offset + delta)
                        .clamp(0.0, position.maxScrollExtent);
                    _horizontalController.jumpTo(target);
                  },
                  child: Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: scrollableX,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: scrollableY,
                        notificationPredicate: (notification) =>
                            notification.depth == 0,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          scrollDirection: Axis.vertical,
                          child: SizedBox(
                            width: planWidth,
                            height: planHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _PlanPainter(plan: plan),
                                  ),
                                ),
                                for (
                                  var index = 0;
                                  index < plan.cells.length;
                                  index++
                                )
                                  Positioned.fromRect(
                                    rect: plan.cells[index].rect,
                                    child: _SeatCell(
                                      names: [
                                        for (final seat
                                            in plan.cells[index].seatIndexes)
                                          seat < widget.students.length
                                              ? widget.students[seat].fullName
                                              : '',
                                      ],
                                      isPair: plan.cells[index].isPair,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  widget.students.isEmpty
                      ? Icons.event_seat_outlined
                      : Icons.groups_outlined,
                  size: 16,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.students.isEmpty
                        ? 'Boş sandalyeler gösteriliyor'
                        : '${widget.students.length} öğrenci yerleştirildi'
                              '${plan.overflowCount > 0 ? ' • ${plan.overflowCount} öğrenci harita dışında' : ''}',
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (scrollableX || scrollableY)
                  const Text(
                    'Kaydırın',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Sandalye hücresi: tekli hücrede bir sandalye, çiftli hücrede iki sandalye.
class SeatCell {
  const SeatCell({
    required this.rect,
    required this.seatIndexes,
    this.isPair = false,
  });

  final Rect rect;

  /// Bu hücredeki sandalyelerin sıra numaraları.
  final List<int> seatIndexes;
  final bool isPair;
}

/// Düzenin geometrisini üreten planlayıcı.
class SeatPlan {
  const SeatPlan({
    required this.cells,
    required this.canvasSize,
    required this.tables,
    this.board,
    this.overflowCount = 0,
  });

  final List<SeatCell> cells;
  final Size canvasSize;
  final List<Rect> tables;
  final Rect? board;
  final int overflowCount;

  static const _maxCells = 60;

  static SeatPlan of({
    required StudyRoomSeating seating,
    required StudyRoomLayout layout,
    required int tableSize,
    required bool tablesHaveStudents,
    required int studentCount,
  }) {
    switch (seating) {
      case StudyRoomSeating.single:
        return _grid(
          layout: layout,
          columns: layout.columns,
          rows: layout.rows,
          pair: false,
          studentCount: studentCount,
        );
      case StudyRoomSeating.pair:
        return _grid(
          layout: layout,
          columns: layout.columns,
          rows: layout.rows,
          pair: true,
          studentCount: studentCount,
        );
      case StudyRoomSeating.horseshoe:
        return _horseshoe(layout: layout, studentCount: studentCount);
      case StudyRoomSeating.groupTables:
        return _groupTables(
          layout: layout,
          tableSize: tableSize,
          tablesHaveStudents: tablesHaveStudents,
          studentCount: studentCount,
        );
    }
  }

  /// Tekli ve çiftli sıralar: yana (sütun) ve arkaya (satır) sıra sayısı.
  static SeatPlan _grid({
    required StudyRoomLayout layout,
    required int columns,
    required int rows,
    required bool pair,
    required int studentCount,
  }) {
    final columnGap = 10.0;
    final rowGap = 12.0;
    final cellWidth = pair ? 168.0 : 88.0;
    final cellHeight = 34.0;
    final totalColumns = math.max(1, columns);
    final totalRows = math.max(1, rows);
    final canvas = Size(
      totalColumns * cellWidth + (totalColumns - 1) * columnGap + 12,
      totalRows * cellHeight + (totalRows - 1) * rowGap + (pair ? 34 : 12),
    );
    final board = pair ? null : Rect.fromLTWH(6, 0, canvas.width - 12, 10);
    final top = board == null ? 0 : board.height + 8;
    final cells = <SeatCell>[];
    var index = 0;
    for (var row = 0; row < totalRows; row++) {
      for (var column = 0; column < totalColumns; column++) {
        if (index >= _maxCells) {
          break;
        }
        final rect = Rect.fromLTWH(
          column * (cellWidth + columnGap) + 6,
          top + row * (cellHeight + rowGap),
          cellWidth,
          cellHeight,
        );
        final seatCount = pair ? 2 : 1;
        final seatIndexes = [
          for (var seat = 0; seat < seatCount; seat++) index * seatCount + seat,
        ];
        cells.add(SeatCell(rect: rect, seatIndexes: seatIndexes, isPair: pair));
        index++;
      }
    }
    final totalSeats = cells.length * (pair ? 2 : 1);
    return SeatPlan(
      cells: cells,
      canvasSize: canvas,
      tables: const [],
      board: board,
      overflowCount: math.max(0, studentCount - totalSeats),
    );
  }

  static SeatPlan _horseshoe({
    required StudyRoomLayout layout,
    required int studentCount,
  }) {
    const seatWidth = 88.0;
    const seatHeight = 34.0;
    const gap = 10.0;
    final legs = math.max(1, layout.uLeftSeats);
    final rightLegs = math.max(1, layout.uRightSeats);
    final base = math.max(2, layout.uBaseSeats);
    final legHeight = legs * (seatHeight + gap) - gap;
    final rightLegHeight = rightLegs * (seatHeight + gap) - gap;
    final bodyHeight = math.max(legHeight, rightLegHeight);
    final baseWidth = base * (seatWidth + gap) - gap;
    final canvas = Size(
      baseWidth + (seatWidth + gap) * 2,
      bodyHeight + (seatHeight + gap),
    );
    final cells = <SeatCell>[];
    var index = 0;
    // Sol bacak: yukarıdan aşağıya.
    for (var seat = 0; seat < legs && index < _maxCells; seat++) {
      cells.add(
        SeatCell(
          rect: Rect.fromLTWH(
            0,
            seat * (seatHeight + gap),
            seatWidth,
            seatHeight,
          ),
          seatIndexes: [index],
        ),
      );
      index++;
    }
    // Sağ bacak: yukarıdan aşağıya.
    for (var seat = 0; seat < rightLegs && index < _maxCells; seat++) {
      cells.add(
        SeatCell(
          rect: Rect.fromLTWH(
            canvas.width - seatWidth,
            seat * (seatHeight + gap),
            seatWidth,
            seatHeight,
          ),
          seatIndexes: [index],
        ),
      );
      index++;
    }
    // Taban: soldan sağa.
    for (var seat = 0; seat < base && index < _maxCells; seat++) {
      cells.add(
        SeatCell(
          rect: Rect.fromLTWH(
            seatWidth + gap + seat * (seatWidth + gap),
            math.max(legHeight, rightLegHeight),
            seatWidth,
            seatHeight,
          ),
          seatIndexes: [index],
        ),
      );
      index++;
    }
    return SeatPlan(
      cells: cells,
      canvasSize: canvas,
      tables: const [],
      overflowCount: math.max(0, studentCount - index),
    );
  }

  static SeatPlan _groupTables({
    required StudyRoomLayout layout,
    required int tableSize,
    required bool tablesHaveStudents,
    required int studentCount,
  }) {
    final columns = math.max(1, layout.tableColumns);
    final rows = math.max(1, layout.tableRows);
    final perTable = math.max(2, tableSize) + (tablesHaveStudents ? 2 : 0);
    const seatWidth = 62.0;
    const seatHeight = 30.0;
    const gap = 8.0;
    final tableWidth = math.max(84.0, perTable * seatWidth * 0.62);
    final tableHeight = math.max(56.0, seatHeight * 1.6);
    final cellWidth = tableWidth + seatWidth * 2 + gap * 2;
    final cellHeight = tableHeight + seatHeight * 2 + gap * 2;
    final canvas = Size(cellWidth * columns, cellHeight * rows);
    final tables = <Rect>[];
    final cells = <SeatCell>[];
    var index = 0;
    for (var tableIndex = 0; tableIndex < columns * rows; tableIndex++) {
      final row = tableIndex ~/ columns;
      final column = tableIndex % columns;
      final center = Offset(
        cellWidth * column + cellWidth / 2,
        cellHeight * row + cellHeight / 2,
      );
      tables.add(
        Rect.fromCenter(center: center, width: tableWidth, height: tableHeight),
      );
      for (var seat = 0; seat < perTable; seat++) {
        if (index >= _maxCells) {
          break;
        }
        final angle = 2 * math.pi * seat / perTable - math.pi / 2;
        final point =
            center +
            Offset(
              math.cos(angle) * (tableWidth / 2 + seatWidth * 0.55 + gap / 2),
              math.sin(angle) * (tableHeight / 2 + seatHeight * 0.6 + gap / 2),
            );
        cells.add(
          SeatCell(
            rect: Rect.fromCenter(
              center: point,
              width: seatWidth,
              height: seatHeight,
            ),
            seatIndexes: [index],
          ),
        );
        index++;
      }
    }
    return SeatPlan(
      cells: cells,
      canvasSize: canvas,
      tables: tables,
      overflowCount: math.max(0, studentCount - index),
    );
  }
}

/// Masa ve sandalye çerçevelerini çizer.
class _PlanPainter extends CustomPainter {
  const _PlanPainter({required this.plan});

  final SeatPlan plan;

  @override
  void paint(Canvas canvas, Size size) {
    final board = plan.board;
    if (board != null) {
      final rect = RRect.fromRectAndRadius(board, const Radius.circular(4));
      canvas.drawRRect(
        rect,
        Paint()..color = AppColors.secondary.withValues(alpha: 0.2),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = AppColors.secondary.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    for (final table in plan.tables) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(table, const Radius.circular(10)),
        Paint()..color = AppColors.primary.withValues(alpha: 0.12),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(table, const Radius.circular(10)),
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    for (final cell in plan.cells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cell.rect, const Radius.circular(6)),
        Paint()
          ..color = AppColors.inputBorder.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_PlanPainter oldDelegate) =>
      oldDelegate.plan.cells.length != plan.cells.length;
}

/// Sandalye hücresi: çiftli düzende iki isim tek kutuda, tekli düzende bir isim.
class _SeatCell extends StatelessWidget {
  const _SeatCell({required this.names, required this.isPair});

  final List<String> names;
  final bool isPair;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < (isPair ? 2 : 1); index++) ...[
          if (isPair)
            Expanded(
              child: _SeatLabel(name: index < names.length ? names[index] : ''),
            )
          else
            Expanded(child: _SeatLabel(name: names.isEmpty ? '' : names.first)),
          if (isPair && index == 0)
            Container(
              width: 1,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
        ],
      ],
    );
  }
}

class _SeatLabel extends StatelessWidget {
  const _SeatLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final filled = name.isNotEmpty;
    return Tooltip(
      message: filled ? name : 'Boş sandalye',
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: filled
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: filled
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.inputBorder,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            filled ? shortenStudentName(name) : '',
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Uzun isimleri kısaltır: soy isim baş harf ve nokta ile gösterilir.
///
/// `Zeynep Kaya` -> `Zeynep K.`, `Mehmet Ahmetoğulları` -> `Mehmet A.`
String shortenStudentName(String fullName) {
  final parts = fullName
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return fullName;
  }
  final given = parts.first;
  if (parts.length == 1) {
    return given.length <= 10 ? given : '${given.substring(0, 9)}…';
  }
  final surname = parts[1].characters.first.toUpperCase();
  return '$given $surname.';
}
