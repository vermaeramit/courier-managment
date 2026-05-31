/* ============================================================================
   Courier Management System (MVP)
   02_stored_procedures.sql  -  one proc per operation.
   Naming convention: usp_<Entity>_<Action>
   Multi-table writes run inside BEGIN TRAN ... COMMIT with SET XACT_ABORT ON.
   Parameter names (minus @) match the C# request-DTO property names so Dapper
   maps them with no manual wiring.
   ============================================================================ */

USE CourierMvp;
GO
SET NOCOUNT ON;
GO

/* ==========================================================================
   AUTH & USERS
   ========================================================================== */

CREATE OR ALTER PROCEDURE dbo.usp_User_GetByEmail
    @Email NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  u.Id, u.BranchId, u.Name, u.Role, u.Phone, u.Email,
            u.PasswordHash, u.Status, u.CreatedAt,
            b.Code AS BranchCode, b.Name AS BranchName
    FROM    dbo.Users u
    LEFT JOIN dbo.Branches b ON b.Id = u.BranchId
    WHERE   u.Email = @Email;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_User_GetById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  u.Id, u.BranchId, u.Name, u.Role, u.Phone, u.Email,
            u.Status, u.CreatedAt,
            b.Code AS BranchCode, b.Name AS BranchName
    FROM    dbo.Users u
    LEFT JOIN dbo.Branches b ON b.Id = u.BranchId
    WHERE   u.Id = @Id;
END
GO

-- Admin sees all; manager scoped to own branch (pass @ScopeBranchId, NULL = no filter).
CREATE OR ALTER PROCEDURE dbo.usp_User_List
    @ScopeBranchId INT = NULL,
    @Role          NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  u.Id, u.BranchId, u.Name, u.Role, u.Phone, u.Email,
            u.Status, u.CreatedAt,
            b.Code AS BranchCode, b.Name AS BranchName
    FROM    dbo.Users u
    LEFT JOIN dbo.Branches b ON b.Id = u.BranchId
    WHERE   (@ScopeBranchId IS NULL OR u.BranchId = @ScopeBranchId)
      AND   (@Role IS NULL OR u.Role = @Role)
    ORDER BY u.Name;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_User_Create
    @BranchId     INT = NULL,
    @Name         NVARCHAR(150),
    @Role         NVARCHAR(20),
    @Phone        NVARCHAR(20) = NULL,
    @Email        NVARCHAR(150),
    @PasswordHash NVARCHAR(500),
    @Status       NVARCHAR(20) = N'Active'
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Users (BranchId, Name, Role, Phone, Email, PasswordHash, Status)
    VALUES (@BranchId, @Name, @Role, @Phone, @Email, @PasswordHash, @Status);

    EXEC dbo.usp_User_GetById @Id = @@IDENTITY;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_User_Update
    @Id       INT,
    @BranchId INT = NULL,
    @Name     NVARCHAR(150),
    @Role     NVARCHAR(20),
    @Phone    NVARCHAR(20) = NULL,
    @Status   NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Users
    SET BranchId = @BranchId,
        Name     = @Name,
        Role     = @Role,
        Phone    = @Phone,
        Status   = @Status
    WHERE Id = @Id;

    EXEC dbo.usp_User_GetById @Id = @Id;
END
GO

/* ==========================================================================
   BRANCHES  (admin only at the app layer)
   ========================================================================== */

CREATE OR ALTER PROCEDURE dbo.usp_Branch_List
    @OnlyActive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  Id, Code, Name, City, Pincode, ManagerId, IsActive, CreatedAt
    FROM    dbo.Branches
    WHERE   (@OnlyActive = 0 OR IsActive = 1)
    ORDER BY Code;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Branch_GetById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Id, Code, Name, City, Pincode, ManagerId, IsActive, CreatedAt
    FROM dbo.Branches WHERE Id = @Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Branch_Create
    @Code      NVARCHAR(10),
    @Name      NVARCHAR(150),
    @City      NVARCHAR(100),
    @Pincode   NVARCHAR(10),
    @ManagerId INT = NULL,
    @IsActive  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Branches (Code, Name, City, Pincode, ManagerId, IsActive)
    VALUES (@Code, @Name, @City, @Pincode, @ManagerId, @IsActive);

    EXEC dbo.usp_Branch_GetById @Id = @@IDENTITY;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Branch_Update
    @Id        INT,
    @Name      NVARCHAR(150),
    @City      NVARCHAR(100),
    @Pincode   NVARCHAR(10),
    @ManagerId INT = NULL,
    @IsActive  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Branches
    SET Name = @Name, City = @City, Pincode = @Pincode,
        ManagerId = @ManagerId, IsActive = @IsActive
    WHERE Id = @Id;

    EXEC dbo.usp_Branch_GetById @Id = @Id;
END
GO

/* ==========================================================================
   SERVICEABILITY
   ========================================================================== */

CREATE OR ALTER PROCEDURE dbo.usp_Pincode_CheckServiceable
    @Pincode NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (1)
           sp.Id, sp.Pincode, sp.BranchId, sp.IsServiceable,
           b.Code AS BranchCode, b.Name AS BranchName
    FROM   dbo.ServiceablePincodes sp
    JOIN   dbo.Branches b ON b.Id = sp.BranchId
    WHERE  sp.Pincode = @Pincode
      AND  sp.IsServiceable = 1
    ORDER BY sp.Id;
END
GO

/* ==========================================================================
   SHIPMENT BOOKING + TRACKING  (the template feature slice)
   ========================================================================== */

/* Create a shipment. Multi-table: Shipments + first TrackingEvent + COD row.
   Generates TrackingId = <OriginBranchCode><8-digit seq>, an invoice number,
   and a barcode value. Validates destination pincode serviceability. */
CREATE OR ALTER PROCEDURE dbo.usp_Shipment_Create
    @OriginBranchId  INT,
    @DestBranchId    INT,
    @SenderName      NVARCHAR(150),
    @SenderPhone     NVARCHAR(20),
    @SenderAddress   NVARCHAR(400),
    @SenderPincode   NVARCHAR(10),
    @ReceiverName    NVARCHAR(150),
    @ReceiverPhone   NVARCHAR(20),
    @ReceiverAddress NVARCHAR(400),
    @ReceiverPincode NVARCHAR(10),
    @Weight          DECIMAL(9,3),
    @ServiceType     NVARCHAR(20),
    @PaymentMode     NVARCHAR(10),
    @CodAmount       DECIMAL(18,2) = 0,
    @CreatedBy       INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Validate destination pincode is serviceable before doing anything.
    IF NOT EXISTS (SELECT 1 FROM dbo.ServiceablePincodes
                   WHERE Pincode = @ReceiverPincode AND IsServiceable = 1)
    BEGIN
        ;THROW 50001, 'Destination pincode is not serviceable.', 1;
    END

    IF @PaymentMode = N'COD' AND @CodAmount <= 0
    BEGIN
        ;THROW 50002, 'COD shipments require a positive COD amount.', 1;
    END

    DECLARE @OriginCode NVARCHAR(10) = (SELECT Code FROM dbo.Branches WHERE Id = @OriginBranchId);
    IF @OriginCode IS NULL
    BEGIN
        ;THROW 50003, 'Origin branch not found.', 1;
    END

    BEGIN TRAN;

        DECLARE @seq BIGINT = NEXT VALUE FOR dbo.Seq_ShipmentNumber;
        DECLARE @TrackingId   NVARCHAR(30) = @OriginCode + RIGHT(REPLICATE('0', 8) + CAST(@seq AS NVARCHAR(8)), 8);
        DECLARE @InvoiceNumber NVARCHAR(30) = N'INV-' + FORMAT(SYSUTCDATETIME(), 'yyyyMMdd') + N'-'
                                              + RIGHT(REPLICATE('0', 6) + CAST(@seq AS NVARCHAR(6)), 6);

        INSERT INTO dbo.Shipments
        (   TrackingId, InvoiceNumber, BarcodeValue, OriginBranchId, DestBranchId, CurrentBranchId,
            SenderName, SenderPhone, SenderAddress, SenderPincode,
            ReceiverName, ReceiverPhone, ReceiverAddress, ReceiverPincode,
            Weight, ServiceType, PaymentMode, CodAmount, Status, CreatedBy )
        VALUES
        (   @TrackingId, @InvoiceNumber, @TrackingId, @OriginBranchId, @DestBranchId, @OriginBranchId,
            @SenderName, @SenderPhone, @SenderAddress, @SenderPincode,
            @ReceiverName, @ReceiverPhone, @ReceiverAddress, @ReceiverPincode,
            @Weight, @ServiceType, @PaymentMode, @CodAmount, N'Booked', @CreatedBy );

        DECLARE @ShipmentId INT = SCOPE_IDENTITY();

        -- First tracking event (audit trail).
        INSERT INTO dbo.TrackingEvents (ShipmentId, Status, BranchId, Remarks)
        VALUES (@ShipmentId, N'Booked', @OriginBranchId, N'Shipment booked');

        -- COD row when applicable.
        IF @PaymentMode = N'COD'
        BEGIN
            INSERT INTO dbo.CodTransactions (ShipmentId, AmountExpected)
            VALUES (@ShipmentId, @CodAmount);
        END

    COMMIT TRAN;

    -- Return the created shipment (header view).
    EXEC dbo.usp_Shipment_GetById @Id = @ShipmentId;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_Shipment_GetById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  s.Id, s.TrackingId, s.InvoiceNumber, s.BarcodeValue,
            s.OriginBranchId, ob.Code AS OriginBranchCode, ob.Name AS OriginBranchName,
            s.DestBranchId,   db.Code AS DestBranchCode,   db.Name AS DestBranchName,
            s.CurrentBranchId,
            s.SenderName, s.SenderPhone, s.SenderAddress, s.SenderPincode,
            s.ReceiverName, s.ReceiverPhone, s.ReceiverAddress, s.ReceiverPincode,
            s.Weight, s.ServiceType, s.PaymentMode, s.CodAmount,
            s.Status, s.AssignedRiderId, r.Name AS AssignedRiderName,
            s.CreatedBy, s.CreatedAt, s.UpdatedAt
    FROM    dbo.Shipments s
    JOIN    dbo.Branches ob ON ob.Id = s.OriginBranchId
    JOIN    dbo.Branches db ON db.Id = s.DestBranchId
    LEFT JOIN dbo.Users  r  ON r.Id  = s.AssignedRiderId
    WHERE   s.Id = @Id;
END
GO

/* Public, unauthenticated tracking. Returns header + full event history.
   Two result sets: [0] shipment summary, [1] events ordered oldest->newest. */
CREATE OR ALTER PROCEDURE dbo.usp_Shipment_GetByTracking
    @TrackingId NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ShipmentId INT = (SELECT Id FROM dbo.Shipments WHERE TrackingId = @TrackingId);

    SELECT  s.TrackingId, s.Status, s.ServiceType, s.PaymentMode,
            ob.Name AS OriginBranchName, ob.City AS OriginCity,
            db.Name AS DestBranchName,   db.City AS DestCity,
            s.ReceiverName, s.CreatedAt, s.UpdatedAt
    FROM    dbo.Shipments s
    JOIN    dbo.Branches ob ON ob.Id = s.OriginBranchId
    JOIN    dbo.Branches db ON db.Id = s.DestBranchId
    WHERE   s.Id = @ShipmentId;

    SELECT  te.Status, te.Remarks, te.Latitude, te.Longitude,
            b.Name AS BranchName, te.CreatedAt
    FROM    dbo.TrackingEvents te
    LEFT JOIN dbo.Branches b ON b.Id = te.BranchId
    WHERE   te.ShipmentId = @ShipmentId
    ORDER BY te.CreatedAt, te.Id;
END
GO

/* Update status + append event. Single-table primary write but always paired
   with an event insert -> wrapped in a transaction. */
CREATE OR ALTER PROCEDURE dbo.usp_Shipment_UpdateStatus
    @ShipmentId INT,
    @Status     NVARCHAR(20),
    @BranchId   INT = NULL,
    @RiderId    INT = NULL,
    @Latitude   DECIMAL(9,6) = NULL,
    @Longitude  DECIMAL(9,6) = NULL,
    @Remarks    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Shipments WHERE Id = @ShipmentId)
    BEGIN
        ;THROW 50010, 'Shipment not found.', 1;
    END

    BEGIN TRAN;

        UPDATE dbo.Shipments
        SET Status = @Status,
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @ShipmentId;

        INSERT INTO dbo.TrackingEvents
            (ShipmentId, Status, BranchId, RiderId, Latitude, Longitude, Remarks)
        VALUES
            (@ShipmentId, @Status, @BranchId, @RiderId, @Latitude, @Longitude, @Remarks);

    COMMIT TRAN;

    EXEC dbo.usp_Shipment_GetById @Id = @ShipmentId;
END
GO

/* Branch-scoped list with optional status filter.
   @ScopeBranchId NULL = admin (all branches). Matches origin OR dest OR current. */
CREATE OR ALTER PROCEDURE dbo.usp_Shipment_List
    @ScopeBranchId INT = NULL,
    @Status        NVARCHAR(20) = NULL,
    @FromDate      DATETIME2(3) = NULL,
    @ToDate        DATETIME2(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  s.Id, s.TrackingId, s.InvoiceNumber,
            s.OriginBranchId, ob.Code AS OriginBranchCode,
            s.DestBranchId,   db.Code AS DestBranchCode,
            s.ReceiverName, s.ReceiverPincode,
            s.ServiceType, s.PaymentMode, s.CodAmount,
            s.Status, s.AssignedRiderId, r.Name AS AssignedRiderName,
            s.CreatedAt, s.UpdatedAt
    FROM    dbo.Shipments s
    JOIN    dbo.Branches ob ON ob.Id = s.OriginBranchId
    JOIN    dbo.Branches db ON db.Id = s.DestBranchId
    LEFT JOIN dbo.Users  r  ON r.Id  = s.AssignedRiderId
    WHERE   (@ScopeBranchId IS NULL
                OR s.OriginBranchId = @ScopeBranchId
                OR s.DestBranchId   = @ScopeBranchId
                OR s.CurrentBranchId = @ScopeBranchId)
      AND   (@Status IS NULL OR s.Status = @Status)
      AND   (@FromDate IS NULL OR s.CreatedAt >= @FromDate)
      AND   (@ToDate   IS NULL OR s.CreatedAt <  @ToDate)
    ORDER BY s.CreatedAt DESC;
END
GO

/* Handoff from origin to destination branch. Moves the parcel's current branch,
   sets InTransit/AtDestinationHub appropriately, and appends an event. */
CREATE OR ALTER PROCEDURE dbo.usp_Shipment_Handoff
    @ShipmentId    INT,
    @ToBranchId    INT,
    @Status        NVARCHAR(20) = N'InTransit',
    @Remarks       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Shipments WHERE Id = @ShipmentId)
        ;THROW 50011, 'Shipment not found.', 1;

    BEGIN TRAN;

        UPDATE dbo.Shipments
        SET CurrentBranchId = @ToBranchId,
            Status = @Status,
            UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @ShipmentId;

        INSERT INTO dbo.TrackingEvents (ShipmentId, Status, BranchId, Remarks)
        VALUES (@ShipmentId, @Status, @ToBranchId,
                ISNULL(@Remarks, N'Handed off to branch ' + CAST(@ToBranchId AS NVARCHAR(10))));

    COMMIT TRAN;

    EXEC dbo.usp_Shipment_GetById @Id = @ShipmentId;
END
GO

/* ==========================================================================
   RIDER
   ========================================================================== */

-- Manual rider assignment to a shipment.
CREATE OR ALTER PROCEDURE dbo.usp_Shipment_AssignRider
    @ShipmentId INT,
    @RiderId    INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @RiderId AND Role = N'Rider')
        ;THROW 50020, 'Assigned user is not a rider.', 1;

    BEGIN TRAN;

        UPDATE dbo.Shipments
        SET AssignedRiderId = @RiderId, UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @ShipmentId;

        -- Keep COD row's rider in sync if COD.
        UPDATE dbo.CodTransactions
        SET RiderId = @RiderId
        WHERE ShipmentId = @ShipmentId;

        INSERT INTO dbo.TrackingEvents (ShipmentId, Status, RiderId, Remarks)
        SELECT @ShipmentId, Status, @RiderId, N'Rider assigned'
        FROM dbo.Shipments WHERE Id = @ShipmentId;

    COMMIT TRAN;

    EXEC dbo.usp_Shipment_GetById @Id = @ShipmentId;
END
GO

-- A rider's daily assigned stop list (out-for-delivery / pickup queue).
CREATE OR ALTER PROCEDURE dbo.usp_Rider_DailyStops
    @RiderId INT,
    @ForDate DATE = NULL          -- defaults to today's UTC date
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @from DATETIME2(3) = CAST(ISNULL(@ForDate, CAST(SYSUTCDATETIME() AS DATE)) AS DATETIME2(3));
    DECLARE @to   DATETIME2(3) = DATEADD(DAY, 1, @from);

    SELECT  s.Id, s.TrackingId, s.Status, s.PaymentMode, s.CodAmount,
            s.ReceiverName, s.ReceiverPhone, s.ReceiverAddress, s.ReceiverPincode,
            db.Name AS DestBranchName,
            c.AmountExpected, c.AmountCollected, c.Deposited
    FROM    dbo.Shipments s
    JOIN    dbo.Branches db ON db.Id = s.DestBranchId
    LEFT JOIN dbo.CodTransactions c ON c.ShipmentId = s.Id
    WHERE   s.AssignedRiderId = @RiderId
      AND   s.Status IN (N'OutForDelivery', N'AtDestinationHub', N'PickedUp')
      AND   s.UpdatedAt >= @from AND s.UpdatedAt < @to
    ORDER BY s.ReceiverPincode, s.Id;
END
GO

/* Submit proof of delivery + mark Delivered. Multi-table:
   ProofOfDelivery + Shipments status + TrackingEvent (+ optional COD collect). */
CREATE OR ALTER PROCEDURE dbo.usp_Pod_Submit
    @ShipmentId     INT,
    @Type           NVARCHAR(20),         -- Photo | OTP | Signature
    @PhotoUrl       NVARCHAR(500) = NULL,
    @Otp            NVARCHAR(10)  = NULL,
    @RiderId        INT,
    @Latitude       DECIMAL(9,6)  = NULL,
    @Longitude      DECIMAL(9,6)  = NULL,
    @CodCollected   DECIMAL(18,2) = NULL, -- when COD shipment
    @Remarks        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Shipments WHERE Id = @ShipmentId)
        ;THROW 50030, 'Shipment not found.', 1;

    -- For OTP delivery, verify supplied OTP matches the one issued for this shipment.
    IF @Type = N'OTP'
    BEGIN
        DECLARE @issued NVARCHAR(10) =
            (SELECT TOP (1) Otp FROM dbo.ProofOfDelivery
             WHERE ShipmentId = @ShipmentId AND Type = N'OTP' AND Otp IS NOT NULL
             ORDER BY Id DESC);
        IF @issued IS NULL OR @issued <> @Otp
            ;THROW 50031, 'OTP verification failed.', 1;
    END

    BEGIN TRAN;

        INSERT INTO dbo.ProofOfDelivery (ShipmentId, Type, PhotoUrl, Otp)
        VALUES (@ShipmentId, @Type, @PhotoUrl, @Otp);

        UPDATE dbo.Shipments
        SET Status = N'Delivered', UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @ShipmentId;

        INSERT INTO dbo.TrackingEvents
            (ShipmentId, Status, RiderId, Latitude, Longitude, Remarks)
        VALUES
            (@ShipmentId, N'Delivered', @RiderId, @Latitude, @Longitude,
             ISNULL(@Remarks, N'Delivered with ' + @Type + N' proof'));

        -- Record COD collection if this is a COD shipment.
        IF @CodCollected IS NOT NULL
        BEGIN
            UPDATE dbo.CodTransactions
            SET AmountCollected = @CodCollected,
                RiderId = @RiderId,
                CollectedAt = SYSUTCDATETIME()
            WHERE ShipmentId = @ShipmentId;
        END

    COMMIT TRAN;

    EXEC dbo.usp_Shipment_GetById @Id = @ShipmentId;
END
GO

-- Issue/refresh an OTP for a shipment (called when out-for-delivery; sent to receiver).
CREATE OR ALTER PROCEDURE dbo.usp_Pod_IssueOtp
    @ShipmentId INT,
    @Otp        NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.ProofOfDelivery (ShipmentId, Type, Otp)
    VALUES (@ShipmentId, N'OTP', @Otp);
    SELECT @ShipmentId AS ShipmentId, @Otp AS Otp;
END
GO

/* ==========================================================================
   COD
   ========================================================================== */

-- Record collected amount (used when COD is collected separately from POD).
CREATE OR ALTER PROCEDURE dbo.usp_Cod_RecordCollection
    @ShipmentId     INT,
    @RiderId        INT,
    @AmountCollected DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.CodTransactions
    SET AmountCollected = @AmountCollected,
        RiderId = @RiderId,
        CollectedAt = SYSUTCDATETIME()
    WHERE ShipmentId = @ShipmentId;

    SELECT Id, ShipmentId, RiderId, AmountExpected, AmountCollected,
           Deposited, CollectedAt, DepositedAt
    FROM dbo.CodTransactions WHERE ShipmentId = @ShipmentId;
END
GO

-- Mark collected cash as deposited (rider hands cash to branch).
CREATE OR ALTER PROCEDURE dbo.usp_Cod_MarkDeposited
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.CodTransactions
    SET Deposited = 1, DepositedAt = SYSUTCDATETIME()
    WHERE ShipmentId = @ShipmentId;

    SELECT Id, ShipmentId, RiderId, AmountExpected, AmountCollected,
           Deposited, CollectedAt, DepositedAt
    FROM dbo.CodTransactions WHERE ShipmentId = @ShipmentId;
END
GO

-- Reconciliation per rider for a date range (expected vs collected vs deposited).
CREATE OR ALTER PROCEDURE dbo.usp_Cod_ReconciliationByRider
    @FromDate DATETIME2(3),
    @ToDate   DATETIME2(3),
    @ScopeBranchId INT = NULL   -- non-admin limits to riders of this branch
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  u.Id AS RiderId, u.Name AS RiderName, u.BranchId,
            COUNT(c.Id)                                   AS CodShipments,
            SUM(c.AmountExpected)                         AS TotalExpected,
            SUM(c.AmountCollected)                        AS TotalCollected,
            SUM(CASE WHEN c.Deposited = 1 THEN c.AmountCollected ELSE 0 END) AS TotalDeposited,
            SUM(c.AmountExpected) - SUM(c.AmountCollected) AS Outstanding
    FROM    dbo.CodTransactions c
    JOIN    dbo.Users u ON u.Id = c.RiderId
    WHERE   c.CollectedAt >= @FromDate AND c.CollectedAt < @ToDate
      AND   (@ScopeBranchId IS NULL OR u.BranchId = @ScopeBranchId)
    GROUP BY u.Id, u.Name, u.BranchId
    ORDER BY u.Name;
END
GO

-- Reconciliation per branch for a date range.
CREATE OR ALTER PROCEDURE dbo.usp_Cod_ReconciliationByBranch
    @FromDate DATETIME2(3),
    @ToDate   DATETIME2(3),
    @ScopeBranchId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  b.Id AS BranchId, b.Code AS BranchCode, b.Name AS BranchName,
            COUNT(c.Id)                                   AS CodShipments,
            SUM(c.AmountExpected)                         AS TotalExpected,
            SUM(c.AmountCollected)                        AS TotalCollected,
            SUM(CASE WHEN c.Deposited = 1 THEN c.AmountCollected ELSE 0 END) AS TotalDeposited,
            SUM(c.AmountExpected) - SUM(c.AmountCollected) AS Outstanding
    FROM    dbo.CodTransactions c
    JOIN    dbo.Shipments s ON s.Id = c.ShipmentId
    JOIN    dbo.Branches  b ON b.Id = s.DestBranchId
    WHERE   c.CollectedAt >= @FromDate AND c.CollectedAt < @ToDate
      AND   (@ScopeBranchId IS NULL OR b.Id = @ScopeBranchId)
    GROUP BY b.Id, b.Code, b.Name
    ORDER BY b.Code;
END
GO

/* ==========================================================================
   DASHBOARD
   ========================================================================== */

CREATE OR ALTER PROCEDURE dbo.usp_Dashboard_DailyCounts
    @ScopeBranchId INT = NULL,
    @ForDate       DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @from DATETIME2(3) = CAST(ISNULL(@ForDate, CAST(SYSUTCDATETIME() AS DATE)) AS DATETIME2(3));
    DECLARE @to   DATETIME2(3) = DATEADD(DAY, 1, @from);

    SELECT
        (SELECT COUNT(*) FROM dbo.Shipments s
         WHERE s.CreatedAt >= @from AND s.CreatedAt < @to
           AND (@ScopeBranchId IS NULL OR s.OriginBranchId = @ScopeBranchId)) AS BookingsToday,

        (SELECT COUNT(*) FROM dbo.Shipments s
         WHERE s.Status = N'Delivered' AND s.UpdatedAt >= @from AND s.UpdatedAt < @to
           AND (@ScopeBranchId IS NULL OR s.DestBranchId = @ScopeBranchId)) AS DeliveriesToday,

        (SELECT COUNT(*) FROM dbo.Shipments s
         WHERE s.Status NOT IN (N'Delivered', N'Failed', N'RTO')
           AND (@ScopeBranchId IS NULL
                OR s.OriginBranchId = @ScopeBranchId
                OR s.DestBranchId   = @ScopeBranchId
                OR s.CurrentBranchId = @ScopeBranchId)) AS PendingShipments,

        (SELECT ISNULL(SUM(c.AmountCollected), 0)
         FROM dbo.CodTransactions c
         JOIN dbo.Shipments s ON s.Id = c.ShipmentId
         WHERE c.CollectedAt >= @from AND c.CollectedAt < @to
           AND (@ScopeBranchId IS NULL OR s.DestBranchId = @ScopeBranchId)) AS CodCollectedToday;
END
GO

PRINT 'Stored procedures created.';
GO
