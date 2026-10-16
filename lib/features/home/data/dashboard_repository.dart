import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_repository.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_repository.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';

class DashboardSummary {
  const DashboardSummary({
    this.schoolName,
    this.boardingType,
    this.educationLevel,
    required this.studentCount,
    required this.roomCount,
    required this.blockCount,
    required this.totalCapacity,
    required this.occupiedBeds,
    required this.emptyBeds,
    required this.occupancyRate,
    this.todayMeal,
    this.todayMealDate,
    this.todayDutySlots = const [],
  });

  final String? schoolName;
  final BoardingType? boardingType;
  final EducationLevel? educationLevel;
  final int studentCount;
  final int roomCount;
  final int blockCount;
  final int totalCapacity;
  final int occupiedBeds;
  final int emptyBeds;
  final double occupancyRate;

  /// Günün menüsü; kayıt yoksa `null`.
  final MealDay? todayMeal;

  /// [todayMeal] okunduğu tarih; kart başlığında gün adı gösterilir.
  final DateTime? todayMealDate;

  /// Günün nöbetçi öğretmenleri, nöbet sırasına göre.
  final List<DutyDutySlot> todayDutySlots;

  bool get hasBoardingInfo => schoolName != null;

  /// Bugün için en az bir öğün kaydı var mı?
  ///
  /// Excel içe aktarımı yemeksiz gün satırlarını da yazabildiği için
  /// yalnızca öğün listesinin dolu olması yeterlidir.
  bool get hasTodayMeal => todayMeal?.hasAnyMeal ?? false;
}

abstract interface class DashboardRepository {
  Future<DashboardSummary> load();
}

class RepositoryDashboardRepository implements DashboardRepository {
  RepositoryDashboardRepository({
    required BoardingInfoRepository boardingInfoRepository,
    required StudentRepository studentRepository,
    required RoomRepository roomRepository,
    required MealRepository mealRepository,
    required DutyRepository dutyRepository,
  }) : _boardingInfoRepository = boardingInfoRepository,
       _studentRepository = studentRepository,
       _roomRepository = roomRepository,
       _mealRepository = mealRepository,
       _dutyRepository = dutyRepository;

  final BoardingInfoRepository _boardingInfoRepository;
  final StudentRepository _studentRepository;
  final RoomRepository _roomRepository;
  final MealRepository _mealRepository;
  final DutyRepository _dutyRepository;

  @override
  Future<DashboardSummary> load() async {
    final boardingInfo = await _boardingInfoRepository.load();
    await _roomRepository.syncRooms(boardingInfo);
    final students = await _studentRepository.getStudents();
    final rooms = await _roomRepository.getRooms();

    var totalCapacity = 0;
    var occupiedBeds = 0;
    for (final room in rooms) {
      totalCapacity += room.capacity;
      occupiedBeds += room.occupantCount;
    }
    final emptyBeds = (totalCapacity - occupiedBeds)
        .clamp(0, totalCapacity)
        .toInt();
    final occupancyRate = totalCapacity == 0
        ? 0.0
        : occupiedBeds / totalCapacity;

    final now = DateTime.now();
    final todayMeal = await _loadTodayMeal(now);
    final todayDutySlots = await _loadTodayDutySlots(now);

    return DashboardSummary(
      schoolName: boardingInfo?.schoolName,
      boardingType: boardingInfo?.boardingType,
      educationLevel: boardingInfo?.educationLevel,
      studentCount: students.length,
      roomCount: rooms.length,
      blockCount: boardingInfo?.blocks.length ?? 0,
      totalCapacity: totalCapacity,
      occupiedBeds: occupiedBeds,
      emptyBeds: emptyBeds,
      occupancyRate: occupancyRate,
      todayMeal: todayMeal,
      todayMealDate: now,
      todayDutySlots: todayDutySlots,
    );
  }

  /// Bugünün menüsü; okunamazsa pano bozulmaz.
  Future<MealDay?> _loadTodayMeal(DateTime date) async {
    try {
      final days = await _mealRepository.getMonth(date.year, date.month);
      return findMealDay(days, date);
    } catch (_) {
      return null;
    }
  }

  /// Günün nöbetçi öğretmenleri; okunamazsa pano bozulmaz.
  Future<List<DutyDutySlot>> _loadTodayDutySlots(DateTime date) async {
    try {
      return await _dutyRepository.getDutySlotsForDate(date);
    } catch (_) {
      return const [];
    }
  }
}