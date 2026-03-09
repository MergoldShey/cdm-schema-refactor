-- OPTIMIZED: Flexible & Scalable Architecture
CREATE TABLE Lab_Metadata (
    TestID INT PRIMARY KEY,
    TestName VARCHAR(100), -- e.g., 'Glucose', 'Systolic BP'
    Unit VARCHAR(20)       -- e.g., 'mg/dL', 'mmHg'
);

CREATE TABLE Optimized_Clinical_Data (
    EntryID SERIAL PRIMARY KEY,
    PatientID INT,
    VisitDate TIMESTAMP,
    TestID INT REFERENCES Lab_Metadata(TestID),
    TestValue FLOAT,
    AuditTrail_Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- 21 CFR Part 11 Logic
);