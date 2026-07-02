# Comprehensive Code Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all critical bugs, improve code quality, and add comprehensive test coverage for the Menstrual-Record Flutter app.

**Architecture:** This plan follows a 4-phase approach: (1) Critical bug fixes, (2) Comprehensive testing, (3) Code quality improvements, (4) Verification. Each phase builds on the previous one, ensuring that fixes are validated by tests.

**Tech Stack:** Flutter ^3.5.4, sqflite ^2.3.0, provider ^6.1.1, flutter_test

## Global Constraints

- Flutter SDK ^3.5.4
- All data is local SQLite (no network operations)
- UI is hardcoded to Chinese (`zh_CN`)
- No code generation (build_runner, freezed, json_serializable not used)
- Follow existing manual serialization style
- Run `flutter analyze` and `flutter test` after each phase

---

## Phase 1: Critical Bug Fixes

### Task 1: Remove Duplicate AppDateUtils Class

**Files:**
- Modify: `lib/providers/period_provider.dart`
- Modify: `lib/utils/date_utils.dart` (add missing methods if needed)

**Interfaces:**
- Consumes: `AppDateUtils` from `lib/utils/date_utils.dart`
- Produces: Single `AppDateUtils` class with all required methods

- [ ] **Step 1: Check current AppDateUtils implementations**

Read both files to understand the differences between the two `AppDateUtils` classes.

```bash
# Check what methods exist in each file
```

- [ ] **Step 2: Identify missing methods in utils/date_utils.dart**

Compare the two classes and identify any methods that exist in `period_provider.dart` but not in `utils/date_utils.dart`.

- [ ] **Step 3: Add missing methods to utils/date_utils.dart**

Add any missing methods to `lib/utils/date_utils.dart`:

```dart
// Add to lib/utils/date_utils.dart if missing
static List<DateTime> getDaysInRange(DateTime start, DateTime end) {
  final days = <DateTime>[];
  var current = startOfDay(start);
  final last = startOfDay(end);
  while (current.isBefore(last) || isSameDay(current, last)) {
    days.add(current);
    current = current.add(const Duration(days: 1));
  }
  return days;
}
```

- [ ] **Step 4: Remove duplicate AppDateUtils from period_provider.dart**

Remove the local `AppDateUtils` class from `lib/providers/period_provider.dart` (lines 355-378).

- [ ] **Step 5: Add import for AppDateUtils**

Add the import at the top of `lib/providers/period_provider.dart`:

```dart
import '../utils/date_utils.dart';
```

- [ ] **Step 6: Run flutter analyze to verify**

```bash
flutter analyze
```

Expected: No errors related to `AppDateUtils`

- [ ] **Step 7: Commit changes**

```bash
git add lib/providers/period_provider.dart lib/utils/date_utils.dart
git commit -m "fix: remove duplicate AppDateUtils class, use single import"
```

---

### Task 2: Replace Deprecated withOpacity Calls

**Files:**
- Modify: `lib/screens/record_screen.dart`

**Interfaces:**
- Consumes: None
- Produces: Updated color calls using `withValues`

- [ ] **Step 1: Find all withOpacity calls**

```bash
grep -n "withOpacity" lib/screens/record_screen.dart
```

- [ ] **Step 2: Replace withOpacity with withValues**

Replace all instances of `withOpacity(0.x)` with `withValues(alpha: 0.x)`:

```dart
// Before
AppColors.primaryPink.withOpacity(0.15)

// After
AppColors.primaryPink.withValues(alpha: 0.15)
```

- [ ] **Step 3: Run flutter analyze to verify**

```bash
flutter analyze
```

Expected: No deprecation warnings for `withOpacity`

- [ ] **Step 4: Commit changes**

```bash
git add lib/screens/record_screen.dart
git commit -m "fix: replace deprecated withOpacity with withValues"
```

---

### Task 3: Replace Deprecated cacheExtent Property

**Files:**
- Modify: `lib/screens/record_screen.dart`

**Interfaces:**
- Consumes: None
- Produces: Updated ListView.builder with scrollCacheExtent

- [ ] **Step 1: Find the cacheExtent usage**

```bash
grep -n "cacheExtent" lib/screens/record_screen.dart
```

- [ ] **Step 2: Replace cacheExtent with scrollCacheExtent**

```dart
// Before (line 1036)
cacheExtent: 800,

// After
scrollCacheExtent: 800,
```

- [ ] **Step 3: Run flutter analyze to verify**

```bash
flutter analyze
```

Expected: No deprecation warnings for `cacheExtent`

- [ ] **Step 4: Commit changes**

```bash
git add lib/screens/record_screen.dart
git commit -m "fix: replace deprecated cacheExtent with scrollCacheExtent"
```

---

### Task 4: Run Phase 1 Verification

- [ ] **Step 1: Run flutter analyze**

```bash
flutter analyze
```

Expected: Fewer warnings than before

- [ ] **Step 2: Run flutter test**

```bash
flutter test
```

Expected: All tests pass

- [ ] **Step 3: Commit verification (if any changes needed)**

```bash
git add .
git commit -m "chore: verify phase 1 fixes"
```

---

## Phase 2: Comprehensive Testing

### Task 5: Create Test Directory Structure

**Files:**
- Create: `test/services/prediction_service_test.dart`
- Create: `test/providers/period_provider_test.dart`
- Create: `test/utils/date_utils_test.dart`

**Interfaces:**
- Consumes: None
- Produces: Test files ready for implementation

- [ ] **Step 1: Create test directories**

```bash
mkdir -p test/services test/providers test/utils
```

- [ ] **Step 2: Create placeholder test files**

Create empty test files with basic structure:

```dart
// test/services/prediction_service_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PredictionService', () {
    // Tests will be added here
  });
}
```

```dart
// test/providers/period_provider_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PeriodProvider', () {
    // Tests will be added here
  });
}
```

```dart
// test/utils/date_utils_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDateUtils', () {
    // Tests will be added here
  });
}
```

- [ ] **Step 3: Commit test structure**

```bash
git add test/services/ test/providers/ test/utils/
git commit -m "test: create test directory structure"
```

---

### Task 6: Write PredictionService Unit Tests

**Files:**
- Modify: `test/services/prediction_service_test.dart`

**Interfaces:**
- Consumes: `PredictionService` from `lib/services/prediction_service.dart`
- Produces: Comprehensive test suite for prediction algorithms

- [ ] **Step 1: Write test for empty records**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yimaflutter/services/prediction_service.dart';
import 'package:yimaflutter/models/period_record.dart';

void main() {
  group('PredictionService', () {
    group('calculateCycleData', () {
      test('returns default values for empty records', () {
        final result = PredictionService.calculateCycleData([]);
        
        expect(result.averageCycleLength, 28.0);
        expect(result.averagePeriodLength, 5.0);
        expect(result.totalCycles, 0);
        expect(result.recentPeriods, isEmpty);
        expect(result.predictedNextPeriod, isNull);
      });

      test('returns correct data for single record', () {
        final records = [
          PeriodRecord(
            startDate: '2026-01-01',
            endDate: '2026-01-05',
            periodLength: 5,
          ),
        ];
        
        final result = PredictionService.calculateCycleData(records);
        
        expect(result.totalCycles, 1);
        expect(result.averagePeriodLength, 5.0);
        expect(result.lastPeriodStart, DateTime(2026, 1, 1));
      });

      test('calculates correct averages for multiple records', () {
        final records = [
          PeriodRecord(
            startDate: '2026-01-01',
            endDate: '2026-01-05',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2026-01-29',
            endDate: '2026-02-02',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2026-02-26',
            endDate: '2026-03-01',
            periodLength: 4,
          ),
        ];
        
        final result = PredictionService.calculateCycleData(records);
        
        expect(result.totalCycles, 3);
        expect(result.averagePeriodLength, closeTo(4.67, 0.1));
        expect(result.averageCycleLength, closeTo(28.0, 0.1));
      });
    });

    group('simple algorithm', () {
      test('predicts next period correctly', () {
        final records = [
          PeriodRecord(
            startDate: '2026-01-01',
            endDate: '2026-01-05',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2026-01-29',
            endDate: '2026-02-02',
            periodLength: 5,
          ),
        ];
        
        final result = PredictionService.calculateCycleData(
          records,
          algorithm: 'simple',
        );
        
        expect(result.predictedNextPeriod, DateTime(2026, 2, 26));
      });
    });

    group('weighted algorithm', () {
      test('gives higher weight to recent records', () {
        final records = [
          PeriodRecord(
            startDate: '2025-10-01',
            endDate: '2025-10-05',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2025-10-29',
            endDate: '2025-11-02',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2025-11-26',
            endDate: '2025-11-30',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2025-12-24',
            endDate: '2025-12-28',
            periodLength: 5,
          ),
          PeriodRecord(
            startDate: '2026-01-21',
            endDate: '2026-01-25',
            periodLength: 5,
          ),
        ];
        
        final result = PredictionService.calculateCycleData(
          records,
          algorithm: 'weighted',
        );
        
        // Weighted average should be closer to recent cycle lengths
        expect(result.averageCycleLength, closeTo(28.0, 0.1));
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
flutter test test/services/prediction_service_test.dart
```

Expected: All tests pass

- [ ] **Step 3: Commit tests**

```bash
git add test/services/prediction_service_test.dart
git commit -m "test: add PredictionService unit tests"
```

---

### Task 7: Write AppDateUtils Unit Tests

**Files:**
- Modify: `test/utils/date_utils_test.dart`

**Interfaces:**
- Consumes: `AppDateUtils` from `lib/utils/date_utils.dart`
- Produces: Comprehensive test suite for date utilities

- [ ] **Step 1: Write date utility tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yimaflutter/utils/date_utils.dart';

void main() {
  group('AppDateUtils', () {
    group('isSameDay', () {
      test('returns true for same day', () {
        final date1 = DateTime(2026, 7, 1, 10, 30);
        final date2 = DateTime(2026, 7, 1, 15, 45);
        expect(AppDateUtils.isSameDay(date1, date2), isTrue);
      });

      test('returns false for different days', () {
        final date1 = DateTime(2026, 7, 1);
        final date2 = DateTime(2026, 7, 2);
        expect(AppDateUtils.isSameDay(date1, date2), isFalse);
      });

      test('returns false for different months', () {
        final date1 = DateTime(2026, 6, 30);
        final date2 = DateTime(2026, 7, 1);
        expect(AppDateUtils.isSameDay(date1, date2), isFalse);
      });
    });

    group('isInRange', () {
      test('returns true for date in range', () {
        final date = DateTime(2026, 7, 5);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isTrue);
      });

      test('returns true for start date', () {
        final date = DateTime(2026, 7, 1);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isTrue);
      });

      test('returns true for end date', () {
        final date = DateTime(2026, 7, 10);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isTrue);
      });

      test('returns false for date before range', () {
        final date = DateTime(2026, 6, 30);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isFalse);
      });

      test('returns false for date after range', () {
        final date = DateTime(2026, 7, 11);
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 10);
        expect(AppDateUtils.isInRange(date, start, end), isFalse);
      });

      test('handles null end date', () {
        final date = DateTime(2026, 7, 5);
        final start = DateTime(2026, 7, 1);
        expect(AppDateUtils.isInRange(date, start, null), isTrue);
      });
    });

    group('getDaysInRange', () {
      test('returns correct days for range', () {
        final start = DateTime(2026, 7, 1);
        final end = DateTime(2026, 7, 5);
        final days = AppDateUtils.getDaysInRange(start, end);
        
        expect(days.length, 5);
        expect(days[0], DateTime(2026, 7, 1));
        expect(days[4], DateTime(2026, 7, 5));
      });

      test('handles single day range', () {
        final date = DateTime(2026, 7, 1);
        final days = AppDateUtils.getDaysInRange(date, date);
        
        expect(days.length, 1);
        expect(days[0], DateTime(2026, 7, 1));
      });
    });

    group('daysBetween', () {
      test('calculates correct days between dates', () {
        final date1 = DateTime(2026, 7, 1);
        final date2 = DateTime(2026, 7, 5);
        expect(AppDateUtils.daysBetween(date1, date2), 4);
      });

      test('handles reverse order', () {
        final date1 = DateTime(2026, 7, 5);
        final date2 = DateTime(2026, 7, 1);
        expect(AppDateUtils.daysBetween(date1, date2), 4);
      });

      test('returns 0 for same date', () {
        final date = DateTime(2026, 7, 1);
        expect(AppDateUtils.daysBetween(date, date), 0);
      });
    });

    group('formatDate', () {
      test('formats date correctly', () {
        final date = DateTime(2026, 7, 1);
        expect(AppDateUtils.formatDate(date), '2026-07-01');
      });

      test('pads single digit month and day', () {
        final date = DateTime(2026, 1, 5);
        expect(AppDateUtils.formatDate(date), '2026-01-05');
      });
    });

    group('today', () {
      test('returns today without time', () {
        final today = AppDateUtils.today();
        final now = DateTime.now();
        
        expect(today.year, now.year);
        expect(today.month, now.month);
        expect(today.day, now.day);
        expect(today.hour, 0);
        expect(today.minute, 0);
        expect(today.second, 0);
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
flutter test test/utils/date_utils_test.dart
```

Expected: All tests pass

- [ ] **Step 3: Commit tests**

```bash
git add test/utils/date_utils_test.dart
git commit -m "test: add AppDateUtils unit tests"
```

---

### Task 8: Write PeriodProvider Unit Tests

**Files:**
- Modify: `test/providers/period_provider_test.dart`

**Interfaces:**
- Consumes: `PeriodProvider` from `lib/providers/period_provider.dart`
- Produces: Comprehensive test suite for period provider logic

- [ ] **Step 1: Setup test database**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yimaflutter/providers/period_provider.dart';
import 'package:yimaflutter/models/period_record.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PeriodProvider', () {
    late PeriodProvider provider;

    setUp(() {
      provider = PeriodProvider();
    });

    tearDown(() async {
      // Clean up test database
    });

    group('isPeriodDay', () {
      test('returns true for day in completed period', () async {
        // Add a completed period record
        await provider.savePeriodRecord(
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 5),
        );

        expect(provider.isPeriodDay(DateTime(2026, 7, 3)), isTrue);
      });

      test('returns false for day outside period', () async {
        await provider.savePeriodRecord(
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 5),
        );

        expect(provider.isPeriodDay(DateTime(2026, 7, 6)), isFalse);
      });
    });

    group('getDayType', () {
      test('returns period for period day', () async {
        await provider.savePeriodRecord(
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 5),
        );

        expect(provider.getDayType(DateTime(2026, 7, 3)), 'period');
      });

      test('returns normal for non-special day', () async {
        await provider.savePeriodRecord(
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 5),
        );

        // Day far in the future should be normal
        expect(provider.getDayType(DateTime(2026, 12, 1)), 'normal');
      });
    });

    group('isDateInAnyRecord', () {
      test('returns true for date in record', () async {
        await provider.savePeriodRecord(
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 5),
        );

        expect(provider.isDateInAnyRecord(DateTime(2026, 7, 3)), isTrue);
      });

      test('returns false for date not in any record', () async {
        await provider.savePeriodRecord(
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 5),
        );

        expect(provider.isDateInAnyRecord(DateTime(2026, 7, 6)), isFalse);
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
flutter test test/providers/period_provider_test.dart
```

Expected: All tests pass

- [ ] **Step 3: Commit tests**

```bash
git add test/providers/period_provider_test.dart
git commit -m "test: add PeriodProvider unit tests"
```

---

### Task 9: Run Phase 2 Verification

- [ ] **Step 1: Run all tests**

```bash
flutter test
```

Expected: All tests pass

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: No new errors

- [ ] **Step 3: Commit verification (if any changes needed)**

```bash
git add .
git commit -m "chore: verify phase 2 tests"
```

---

## Phase 3: Code Quality Improvements

### Task 10: Add Missing const Constructors

**Files:**
- Modify: `lib/screens/record_screen.dart`

**Interfaces:**
- Consumes: None
- Produces: Optimized widget tree with const constructors

- [ ] **Step 1: Find missing const constructors**

```bash
flutter analyze | grep "prefer_const_constructors"
```

- [ ] **Step 2: Add const keywords**

Add `const` to constructor calls where Flutter analyze suggests:

```dart
// Example fixes
const Icon(
  Icons.history,
  size: 48,
  color: AppColors.onSurfaceTertiary,
),

const SizedBox(height: AppColors.spacingMd),
```

- [ ] **Step 3: Run flutter analyze to verify**

```bash
flutter analyze
```

Expected: Fewer `prefer_const_constructors` warnings

- [ ] **Step 4: Commit changes**

```bash
git add lib/screens/record_screen.dart
git commit -m "perf: add missing const constructors for better performance"
```

---

### Task 11: Fix _swipeStart Logic

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Interfaces:**
- Consumes: None
- Produces: Corrected swipe gesture detection

- [ ] **Step 1: Review current _swipeStart implementation**

Read the `_onSwipe` method and `_swipeStart` usage in `lib/screens/home_screen.dart`.

- [ ] **Step 2: Fix the swipe detection logic**

The current implementation might have issues with the threshold check. Update the logic:

```dart
void _onSwipe(DragEndDetails details) {
  const threshold = 30.0;
  final velocity = details.primaryVelocity ?? 0;
  
  // Use velocity for swipe detection
  if (velocity > 300) {
    _changeMonth(-1); // Swipe right = previous month
  } else if (velocity < -300) {
    _changeMonth(1); // Swipe left = next month
  }
  
  // Reset swipe start
  _swipeStart = Offset.zero;
}
```

- [ ] **Step 3: Run flutter analyze to verify**

```bash
flutter analyze
```

Expected: No errors

- [ ] **Step 4: Commit changes**

```bash
git add lib/screens/home_screen.dart
git commit -m "fix: improve swipe gesture detection logic"
```

---

### Task 12: Improve Error Handling

**Files:**
- Modify: `lib/database/period_dao.dart`
- Modify: `lib/providers/period_provider.dart`

**Interfaces:**
- Consumes: None
- Produces: Better error handling and user feedback

- [ ] **Step 1: Add error handling to PeriodDao**

Update `lib/database/period_dao.dart` to throw meaningful exceptions:

```dart
Future<int> insert(PeriodRecord record) async {
  try {
    final db = await _dbHelper.database;
    return await db.insert('period_records', record.toMap());
  } catch (e) {
    throw Exception('Failed to insert period record: $e');
  }
}

Future<int> update(PeriodRecord record) async {
  try {
    final db = await _dbHelper.database;
    return await db.update(
      'period_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  } catch (e) {
    throw Exception('Failed to update period record: $e');
  }
}

Future<int> delete(int id) async {
  try {
    final db = await _dbHelper.database;
    return await db.delete(
      'period_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  } catch (e) {
    throw Exception('Failed to delete period record: $e');
  }
}
```

- [ ] **Step 2: Update PeriodProvider error handling**

Update error messages in `lib/providers/period_provider.dart` to be more descriptive:

```dart
Future<bool> startPeriod(DateTime startDate) async {
  try {
    final existing = _records.where((r) => r.isOngoing).toList();
    if (existing.isNotEmpty) {
      debugPrint('Cannot start new period: ongoing period exists');
      return false;
    }

    final record = PeriodRecord(
      startDate: startDate.toIso8601String().split('T')[0],
    );

    await _dao.insert(record);
    await loadRecords();
    return true;
  } catch (e) {
    debugPrint('Error starting period: $e');
    return false;
  }
}
```

- [ ] **Step 3: Run flutter analyze to verify**

```bash
flutter analyze
```

Expected: No errors

- [ ] **Step 4: Commit changes**

```bash
git add lib/database/period_dao.dart lib/providers/period_provider.dart
git commit -m "improve: add better error handling to database operations"
```

---

### Task 13: Fix Edge Cases in Date Logic

**Files:**
- Modify: `lib/providers/period_provider.dart`

**Interfaces:**
- Consumes: None
- Produces: Corrected date logic for edge cases

- [ ] **Step 1: Review _isSafeDayDirect method**

Read the `_isSafeDayDirect` method in `lib/providers/period_provider.dart`.

- [ ] **Step 2: Fix the logic to properly check cycle window**

Update the method to ensure it correctly identifies safe days:

```dart
bool _isSafeDayDirect(DateTime date) {
  if (_cycleData == null) return false;
  final lastStart = _cycleData!.lastPeriodStart;
  final predicted = _cycleData!.predictedNextPeriod;
  if (lastStart == null) return false;
  
  // Calculate window end based on predicted or average cycle
  final windowEnd = predicted != null
      ? predicted.add(const Duration(days: 10))
      : lastStart.add(Duration(days: _cycleData!.averageCycleLength.round() + 10));
  
  // Check if date is within the valid window
  return !date.isBefore(lastStart) && !date.isAfter(windowEnd);
}
```

- [ ] **Step 3: Run flutter analyze to verify**

```bash
flutter analyze
```

Expected: No errors

- [ ] **Step 4: Commit changes**

```bash
git add lib/providers/period_provider.dart
git commit -m "fix: correct edge cases in safe day calculation"
```

---

### Task 14: Run Phase 3 Verification

- [ ] **Step 1: Run flutter analyze**

```bash
flutter analyze
```

Expected: Fewer warnings than before

- [ ] **Step 2: Run flutter test**

```bash
flutter test
```

Expected: All tests pass

- [ ] **Step 3: Commit verification (if any changes needed)**

```bash
git add .
git commit -m "chore: verify phase 3 improvements"
```

---

## Phase 4: Final Verification

### Task 15: Final Code Review

- [ ] **Step 1: Review all changes**

Review all modified files to ensure consistency and correctness.

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze
```

Expected: No errors

- [ ] **Step 3: Run flutter test**

```bash
flutter test
```

Expected: All tests pass

- [ ] **Step 4: Manual testing of critical flows**

Test the following manually:
1. Start a new period
2. End a period
3. Add a record via calendar
4. Edit an existing record
5. Delete a record
6. Export data
7. Import data

- [ ] **Step 5: Final commit**

```bash
git add .
git commit -m "chore: complete comprehensive code review"
```

---

## Summary

This plan covers:
- **Phase 1**: Critical bug fixes (duplicate AppDateUtils, deprecated APIs)
- **Phase 2**: Comprehensive testing (PredictionService, AppDateUtils, PeriodProvider)
- **Phase 3**: Code quality improvements (const constructors, swipe logic, error handling)
- **Phase 4**: Final verification

**Total Tasks**: 15
**Estimated Time**: 2-3 days
**Risk Level**: Medium (modifying core logic, but with test coverage)

**Success Criteria**:
1. All critical bugs fixed
2. All tests pass
3. `flutter analyze` shows no errors
4. Core business logic is thoroughly tested
5. No regressions in existing functionality
