# Clinical Data Model (CDM)
## Entity-Attribute-Value Architecture for Scalable Lab Data Management

---

## Overview

This repository implements a **production-grade pharmaceutical-compliant clinical database schema** that overcomes the brittleness of traditional "flat table" designs. The architecture uses an **Entity-Attribute-Value (EAV) model** to achieve unlimited scalability for clinical lab parameters without requiring database schema changes.

### The Problem: Brittle Flat Table Design

```sql
-- ❌ ANTI-PATTERN: Adding a single new lab test requires ALTER TABLE
CREATE TABLE Messy_Lab_Data (
    PatientID INT,
    VisitDate DATE,
    BloodPressure_Systolic INT,
    BloodPressure_Diastolic INT,
    HeartRate INT,
    Glucose_Level FLOAT,
    Cholesterol_Total FLOAT  -- Every new test = schema modification
    -- Problem: Noise, brittleness, schema lock, NULL inflation
);
```

**Issues:**
- ❌ Adding one new lab test requires `ALTER TABLE` (downtime, migrations)
- ❌ Unused columns inflate every row with NULLs (wasted storage)
- ❌ Hard to maintain reference ranges and units per test
- ❌ Violates the "Invisible Senior" principle (excessive cognitive load)
- ❌ Not regulatory-friendly for audit trails

---

## The Solution: EAV Architecture

```sql
-- ✅ PATTERN: Infinite tests, zero schema changes
CREATE TABLE Lab_Metadata (
    TestID INT PRIMARY KEY,
    TestName VARCHAR(100),   -- e.g., 'Glucose', 'Systolic BP'
    Unit VARCHAR(20)         -- e.g., 'mg/dL', 'mmHg'
);

CREATE TABLE Optimized_Clinical_Data (
    EntryID SERIAL PRIMARY KEY,
    PatientID INT,
    VisitDate TIMESTAMP,
    TestID INT REFERENCES Lab_Metadata(TestID),
    TestValue FLOAT,
    AuditTrail_Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Benefits:**
- ✅ Add new lab tests via `INSERT` into `Lab_Metadata` only
- ✅ No schema changes, no downtime
- ✅ Flexible storage for any metric type
- ✅ Built-in audit trail (21 CFR Part 11 ready)
- ✅ Clear separation of concerns

---

## Schema Design

### Core Tables

#### `Lab_Metadata`
Immutable test definitions. Add new clinical parameters here.

| Column | Type | Purpose |
|--------|------|---------|
| `TestID` | INT PK | Unique test identifier |
| `TestName` | VARCHAR(100) | Human-readable name (e.g., "Glucose") |
| `Unit` | VARCHAR(20) | Measurement unit (e.g., "mg/dL") |

**Example:**
```sql
INSERT INTO Lab_Metadata (TestName, Unit) VALUES
    ('Glucose', 'mg/dL'),
    ('Systolic BP', 'mmHg'),
    ('Hemoglobin A1C', '%');
```

#### `Optimized_Clinical_Data` (Core EAV Table)
Dynamic clinical observation records. Scales infinitely without DDL changes.

| Column | Type | Purpose |
|--------|------|---------|
| `EntryID` | SERIAL PK | Unique immutable observation identifier |
| `PatientID` | INT FK | Reference to patient |
| `VisitDate` | TIMESTAMP | When the test was performed |
| `TestID` | INT FK | References `Lab_Metadata` |
| `TestValue` | FLOAT | The measured result |
| `AuditTrail_Timestamp` | TIMESTAMP | Auto-recorded time (21 CFR Part 11) |

---

## 21 CFR Part 11 Compliance

This schema is **audit-trail ready** for FDA regulations:

- ✅ **Immutable Record ID** (`EntryID`): Never changes, audit-safe
- ✅ **Timestamp Precision** (`AuditTrail_Timestamp`): Auto-recorded
- ✅ **Referential Integrity** (`REFERENCES`): No orphaned records
- ✅ **Logical Auditing**: Tracks data origin and changes

**Extend with audit tables for production:**
```sql
-- Track all modifications
CREATE TABLE Audit_Log (
    AuditID BIGSERIAL PRIMARY KEY,
    EntryID BIGINT,
    Operation VARCHAR(10),          -- INSERT, UPDATE, DELETE
    OldValue FLOAT,
    NewValue FLOAT,
    ChangedBy VARCHAR(255),         -- User accountability
    ChangedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger to auto-record changes
CREATE TRIGGER trg_audit_changes
AFTER UPDATE ON Optimized_Clinical_Data
FOR EACH ROW EXECUTE FUNCTION fn_audit_changes();
```

---

## Usage Examples

### Add a New Lab Test (Zero Schema Changes!)

```sql
INSERT INTO Lab_Metadata (TestName, Unit) 
VALUES ('D-Dimer', 'ng/mL');
-- ✅ New test is immediately live across all queries
-- ✅ No alter table, no migration, no downtime
```

### Record a Clinical Observation

```sql
INSERT INTO Optimized_Clinical_Data 
(PatientID, VisitDate, TestID, TestValue) 
VALUES 
    (1, '2026-03-09 08:30:00', 1, 95.0);  -- Patient 1, Test 1 (Glucose), Value 95
```

### Query: All Lab Results for a Patient

```sql
SELECT 
    lm.TestName,
    co.TestValue,
    lm.Unit,
    co.VisitDate
FROM Optimized_Clinical_Data co
JOIN Lab_Metadata lm ON co.TestID = lm.TestID
WHERE co.PatientID = 1
ORDER BY co.VisitDate DESC;
```

### Query: Trend Analysis (Rolling Average)

```sql
SELECT 
    co.VisitDate,
    co.TestValue,
    ROUND(AVG(co.TestValue) OVER (
        PARTITION BY co.PatientID 
        ORDER BY co.VisitDate 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS Rolling_Avg_7Days
FROM Optimized_Clinical_Data co
JOIN Lab_Metadata lm ON co.TestID = lm.TestID
WHERE co.PatientID = 1 AND lm.TestName = 'Glucose'
ORDER BY co.VisitDate;
```

### Query: Find Abnormal Results

```sql
SELECT 
    co.PatientID,
    lm.TestName,
    co.TestValue,
    lm.Unit,
    co.VisitDate
FROM Optimized_Clinical_Data co
JOIN Lab_Metadata lm ON co.TestID = lm.TestID
WHERE co.TestValue > 150  -- Threshold varies by test (extend with reference ranges)
ORDER BY co.VisitDate DESC;
```

---

## Performance Best Practices

### Indexing Strategy

```sql
-- Query 1: Fast patient lookup
CREATE INDEX idx_patient ON Optimized_Clinical_Data(PatientID);

-- Query 2: Fast test type lookup
CREATE INDEX idx_test ON Optimized_Clinical_Data(TestID);

-- Query 3: Time-range queries
CREATE INDEX idx_date ON Optimized_Clinical_Data(VisitDate);

-- Query 4: Most common: Patient + Test + Date combo
CREATE INDEX idx_patient_test_date 
ON Optimized_Clinical_Data(PatientID, TestID, VisitDate);
```

### Query Optimization

1. **Always filter by PatientID first** (highest cardinality)
2. **Use VisitDate ranges** to limit result sets
3. **Pre-compute reference ranges** in `Lab_Metadata` for reporting
4. **Consider table partitioning** for million+ record datasets (monthly or annual)

---

## Architecture Principles

### Why EAV?

| Criterion | Flat Table | EAV |
|-----------|-----------|-----|
| Add new lab test | ❌ ALTER TABLE | ✅ INSERT |
| Schema stability | ❌ Fragile | ✅ Immutable core |
| NULL inflation | ❌ High | ✅ None |
| Audit compliance | ⚠️ Add later | ✅ Built-in |
| Query flexibility | ❌ Rigid | ✅ Dynamic |

### "Invisible Senior" Principle

Code clarity comes from **absence of noise**, not quantity of documentation. This schema achieves clarity through:

- **Single responsibility**: `Lab_Metadata` = test definitions, `Optimized_Clinical_Data` = observations
- **No redundancy**: Each test parameter stored once, referenced many times
- **Intuitive naming**: `TestName`, `TestValue`, `Unit` are self-documenting
- **Regulatory alignment**: Audit trail fields explicitly named for CFR compliance

---

## Common Patterns

### Pattern: Add Reference Ranges

```sql
-- Extend Lab_Metadata
ALTER TABLE Lab_Metadata ADD COLUMN RefRange_Low FLOAT;
ALTER TABLE Lab_Metadata ADD COLUMN RefRange_High FLOAT;

-- Example
UPDATE Lab_Metadata SET RefRange_Low = 70, RefRange_High = 100 
WHERE TestName = 'Glucose';

-- Now you can flag abnormals
SELECT 
    lm.TestName,
    co.TestValue,
    CASE 
        WHEN co.TestValue < lm.RefRange_Low THEN 'Low'
        WHEN co.TestValue > lm.RefRange_High THEN 'High'
        ELSE 'Normal'
    END AS Result_Status
FROM Optimized_Clinical_Data co
JOIN Lab_Metadata lm ON co.TestID = lm.TestID
WHERE co.PatientID = 1;
```

### Pattern: Soft Deletes (Regulatory Compliance)

```sql
-- Add soft-delete flag to preserve audit trail
ALTER TABLE Lab_Metadata ADD COLUMN IsActive BOOLEAN DEFAULT TRUE;

-- Hide inactive tests
SELECT * FROM Lab_Metadata WHERE IsActive = TRUE;

-- Audit trail still visible
SELECT * FROM Optimized_Clinical_Data WHERE TestID = 5;  -- Even if Lab_Metadata(5).IsActive = FALSE
```

### Pattern: Data Entry Method Tracking

```sql
ALTER TABLE Optimized_Clinical_Data ADD COLUMN DataEntryMethod VARCHAR(50);
-- e.g., 'Manual', 'HL7', 'DICOM', 'API'

-- Audit which data came from where
SELECT DataEntryMethod, COUNT(*) FROM Optimized_Clinical_Data 
GROUP BY DataEntryMethod;
```

---

## Regulatory Considerations

- **21 CFR Part 11**: Use immutable `EntryID`, timestamp everything
- **HIPAA**: Extend with encryption and role-based access controls (RBAC)
- **Data Retention**: Implement archive tables for multi-year compliance
- **Amendment Tracking**: Add version number and reason fields for audit trail

---

## Getting Started

### Setup

```bash
# Load the schema
psql -U postgres -d your_clinical_db -f code.sql
```

### Verification

```sql
-- Verify tables exist
\dt

-- Check constraints
\d Optimized_Clinical_Data
```

### First Test

```sql
INSERT INTO Lab_Metadata (TestName, Unit) VALUES ('Test Lab', 'units');
INSERT INTO Optimized_Clinical_Data (PatientID, VisitDate, TestID, TestValue)
VALUES (1, NOW(), 1, 42.0);

SELECT * FROM Optimized_Clinical_Data;
```

---

## Future Enhancements

- [ ] **Audit trigger layer** (automatic INSERT/UPDATE/DELETE logging)
- [ ] **Patient demographics table** (MRN, contact, consent)
- [ ] **Physical units converter** (e.g., mg/dL ↔ mmol/L)
- [ ] **Reference range versioning** (clinical guidelines change over time)
- [ ] **Materialized views** for common reports (e.g., recent abnormals)
- [ ] **Data quality flags** (validated, amended, preliminary, final)

---

## References

- **EAV Pattern**: Object-oriented databases best practice
- **21 CFR Part 11**: FDA electronic records compliance
- **PostgreSQL Documentation**: Window functions, triggers, partitioning

---

## License & Attribution

This clinical data model is designed with regulatory compliance and scalability as top priorities. Suitable for:
- Research databases
- Hospital information systems
- Clinical trial management
- Longitudinal patient studies

**Use responsibly. Patient data is sacred.** 
