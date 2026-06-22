
# Debug Session: student-search-not-found
- **Status**: [OPEN]
- **Start Time**: 2026-06-22
- **Description**: Debugging issue where newly imported students aren't found in registration screen search

## Root Cause Found!
**Hypothesis 4 was correct**: Imported students had invalid year values (fest year like 2026 instead of study year 1‑4), violating the CHECK constraint on student_master.year and preventing insertion!

## Fix Applied:
1. **import_service.dart**: Updated `parseAndValidateCsv` and `parseAndValidateExcel` to validate year as 1‑4 instead of 2020‑2099
2. **historical_import_screen.dart**: Updated sample CSV to use study year
3. **Removed debug instrumentation** from registration_screen.dart

## Steps
- [x] Step 1: Add instrumentation to registration screen _searchStudent
- [x] Step 2: Identify root cause
- [x] Step 3: Implement fix
- [ ] Step 4: Verify fix
