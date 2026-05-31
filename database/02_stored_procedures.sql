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
   STATUS STATE MACHINE
   Single source of truth for which status transitions are legal. Returns 1
   when @From -> @To is allowed. Terminal states (Delivered/RTO) accept no
   onward transition; Failed may still be returned (RTO). A no-op @From=@To
   is rejected so callers can't replay/duplicate a status write.
   ========================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_IsValidStatusTransition
(
    @From NVARCHAR(20),
    @To   NVARCHAR(20)
)
RETURNS BIT
AS
BEGIN
    IF @From IS NULL OR @To IS NULL OR @From = @To
        RETURN 0;

    IF EXISTS
    (
        SELECT 1 FROM (VALUES
            (N'Booked',           N'PickedUp'),
            (N'Booked',           N'Failed'),
            (N'Booked',           N'RTO'),
            (N'PickedUp',         N'AtOriginHub'),
            (N'PickedUp',         N'Failed'),
            (N'PickedUp',         N'RTO'),
            (N'AtOriginHub',      N'InTransit'),
            (N'AtOriginHub',      N'Failed'),
            (N'AtOriginHub',      N'RTO'),
            (N'InTransit',        N'AtDestinationHub'),
            (N'InTransit',        N'Failed'),
            (N'InTransit',        N'RTO'),
            (N'AtDestinationHub', N'OutForDelivery'),
            (N'AtDestinationHub', N'Failed'),
            (N'AtDestinationHub', N'RTO'),
            (N'OutForDelivery',   N'Delivered'),
            (N'OutForDelivery',   N'Failed'),
            (N'OutForDelivery',   N'RTO'),
            (N'Failed',           N'RTO')
        ) AS t(FromStatus, ToStatus)
        WHERE t.FromStatus = @From AND t.ToStatus = @To
    )
        RETURN 1;

    RETURN 0;
END
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

    DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);
    EXEC dbo.usp_User_GetById @Id = @NewId;
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

    DECLARE @NewId INT = CAST(SCOPE_IDENTITY() AS INT);
    EXEC dbo.usp_Branch_GetById @Id = @NewId;
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

    -- Keep PaymentMode and CodAmount coherent (matches CK_Shipments_CodCoherent)
    -- so a stray amount on a Prepaid booking is a clean 400, not a constraint 500.
    IF @PaymentMode = N'Prepaid' AND @CodAmount <> 0
    BEGIN
        ;THROW 50004, 'Prepaid shipments must have a zero COD amount.', 1;
    END

    DECLARE @OriginCode NVARCHAR(10) = (SELECT Code FROM dbo.Branches WHERE Id = @OriginBranchId);
    IF @OriginCode IS NULL
    BEGIN
        ;THROW 50003, 'Origin branch not found.', 1;
    END

    BEGIN TRAN;

        DECLARE @seq BIGINT = NEXT VALUE FOR dbo.Seq_ShipmentNumber;
        -- FORMAT 'D8'/'D6' zero-pads to a minimum width but grows beyond it,
        -- so the numeric portion never truncates (and TrackingId stays unique)
        -- once the sequence exceeds 8 digits.
        DECLARE @TrackingId   NVARCHAR(30) = @OriginCode + FORMAT(@seq, N'D8');
        DECLARE @InvoiceNumber NVARCHAR(30) = N'INV-' + FORMAT(SYSUTCDATETIME(), 'yyyyMMdd') + N'-'
                                              + FORMAT(@seq, N'D6');

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

-- @ScopeBranchId NULL = admin / internal call (no filter). Non-admin callers
-- only see shipments touching their branch (origin, dest, or current) — this
-- closes the IDOR where any authenticated user could read any shipment by id.
CREATE OR ALTER PROCEDURE dbo.usp_Shipment_GetById
    @Id            INT,
    @ScopeBranchId INT = NULL
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
    WHERE   s.Id = @Id
      AND   (@ScopeBranchId IS NULL
                OR s.OriginBranchId  = @ScopeBranchId
                OR s.DestBranchId    = @ScopeBranchId
                OR s.CurrentBranchId = @ScopeBranchId);
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
-- @ScopeBranchId NULL = admin (no branch restriction); otherwise the caller's
-- branch must own the shipment. @RiderScopeId, when supplied (rider caller),
-- additionally requires the shipment to be assigned to that rider.
CREATE OR ALTER PROCEDURE dbo.usp_Shipment_UpdateStatus
    @ShipmentId    INT,
    @Status        NVARCHAR(20),
    @BranchId      INT = NULL,
    @RiderId       INT = NULL,
    @Latitude      DECIMAL(9,6) = NULL,
    @Longitude     DECIMAL(9,6) = NULL,
    @Remarks       NVARCHAR(500) = NULL,
    @ScopeBranchId INT = NULL,
    @RiderScopeId  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

        -- Take an update lock on the row up front so concurrent status writers
        -- serialize: the second caller re-reads the now-current status and its
        -- transition is validated against the committed state (no lost update,
        -- no contradictory audit trail).
        DECLARE @Current NVARCHAR(20), @OwnerBranchOk BIT = 0, @AssignedRider INT;
        SELECT @Current = Status,
               @AssignedRider = AssignedRiderId,
               @OwnerBranchOk = CASE WHEN @ScopeBranchId IS NULL
                                       OR OriginBranchId  = @ScopeBranchId
                                       OR DestBranchId    = @ScopeBranchId
                                       OR CurrentBranchId = @ScopeBranchId
                                     THEN 1 ELSE 0 END
        FROM dbo.Shipments WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @ShipmentId;

        IF @Current IS NULL
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50010, 'Shipment not found.', 1;
        END

        IF @OwnerBranchOk = 0
           OR (@RiderScopeId IS NOT NULL AND (@AssignedRider IS NULL OR @AssignedRider <> @RiderScopeId))
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50012, 'Not authorized for this shipment.', 1;
        END

        IF dbo.fn_IsValidStatusTransition(@Current, @Status) = 0
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50013, 'Illegal status transition.', 1;
        END

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
    @Remarks       NVARCHAR(500) = NULL,
    @ScopeBranchId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

        DECLARE @Current NVARCHAR(20), @OwnerBranchOk BIT = 0;
        SELECT @Current = Status,
               @OwnerBranchOk = CASE WHEN @ScopeBranchId IS NULL
                                       OR OriginBranchId  = @ScopeBranchId
                                       OR DestBranchId    = @ScopeBranchId
                                       OR CurrentBranchId = @ScopeBranchId
                                     THEN 1 ELSE 0 END
        FROM dbo.Shipments WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @ShipmentId;

        IF @Current IS NULL
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50011, 'Shipment not found.', 1;
        END

        IF @OwnerBranchOk = 0
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50014, 'Not authorized for this shipment.', 1;
        END

        IF dbo.fn_IsValidStatusTransition(@Current, @Status) = 0
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50015, 'Illegal status transition for handoff.', 1;
        END

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
    @ShipmentId    INT,
    @RiderId       INT,
    @ScopeBranchId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RiderBranch INT;
    SELECT @RiderBranch = BranchId FROM dbo.Users WHERE Id = @RiderId AND Role = N'Rider';
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Id = @RiderId AND Role = N'Rider')
    BEGIN
        ;THROW 50020, 'Assigned user is not a rider.', 1;
    END

    BEGIN TRAN;

        DECLARE @Current NVARCHAR(20), @OwnerBranchOk BIT = 0,
                @Origin INT, @Dest INT, @CurBranch INT;
        SELECT @Current = Status, @Origin = OriginBranchId, @Dest = DestBranchId,
               @CurBranch = CurrentBranchId,
               @OwnerBranchOk = CASE WHEN @ScopeBranchId IS NULL
                                       OR OriginBranchId  = @ScopeBranchId
                                       OR DestBranchId    = @ScopeBranchId
                                       OR CurrentBranchId = @ScopeBranchId
                                     THEN 1 ELSE 0 END
        FROM dbo.Shipments WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @ShipmentId;

        IF @Current IS NULL
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50021, 'Shipment not found.', 1;
        END

        IF @OwnerBranchOk = 0
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50022, 'Not authorized for this shipment.', 1;
        END

        -- Can't (re)assign a rider to a shipment that has already finished.
        IF @Current IN (N'Delivered', N'Failed', N'RTO')
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50023, 'Cannot assign a rider to a completed shipment.', 1;
        END

        -- Rider must belong to a branch involved in this shipment.
        IF @RiderBranch IS NULL
           OR @RiderBranch NOT IN (@Origin, @Dest, ISNULL(@CurBranch, @Origin))
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50024, 'Rider does not belong to a branch handling this shipment.', 1;
        END

        UPDATE dbo.Shipments
        SET AssignedRiderId = @RiderId, UpdatedAt = SYSUTCDATETIME()
        WHERE Id = @ShipmentId;

        -- Keep COD row's rider in sync if COD.
        UPDATE dbo.CodTransactions
        SET RiderId = @RiderId
        WHERE ShipmentId = @ShipmentId;

        INSERT INTO dbo.TrackingEvents (ShipmentId, Status, RiderId, Remarks)
        VALUES (@ShipmentId, @Current, @RiderId, N'Rider assigned');

    COMMIT TRAN;

    EXEC dbo.usp_Shipment_GetById @Id = @ShipmentId;
END
GO

-- A rider's daily assigned stop list (out-for-delivery / pickup queue).
-- A rider's open stop queue: every shipment currently assigned to them that is
-- still in an actionable state. Previously this filtered on UpdatedAt within the
-- given day, which dropped stops that weren't touched "today" and re-surfaced any
-- shipment whose status was touched for an unrelated reason. We now key purely on
-- assignment + actionable status so the queue is stable across days. @ForDate is
-- retained for API compatibility but no longer narrows the result.
CREATE OR ALTER PROCEDURE dbo.usp_Rider_DailyStops
    @RiderId       INT,
    @ForDate       DATE = NULL,
    @ScopeBranchId INT = NULL   -- non-admin caller: rider must belong to this branch
AS
BEGIN
    SET NOCOUNT ON;

    -- A non-admin may only view stops for a rider in their own branch.
    IF @ScopeBranchId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.Users
                       WHERE Id = @RiderId AND BranchId = @ScopeBranchId)
        RETURN;

    SELECT  s.Id, s.TrackingId, s.Status, s.PaymentMode, s.CodAmount,
            s.ReceiverName, s.ReceiverPhone, s.ReceiverAddress, s.ReceiverPincode,
            db.Name AS DestBranchName,
            c.AmountExpected, c.AmountCollected, c.Deposited
    FROM    dbo.Shipments s
    JOIN    dbo.Branches db ON db.Id = s.DestBranchId
    LEFT JOIN dbo.CodTransactions c ON c.ShipmentId = s.Id
    WHERE   s.AssignedRiderId = @RiderId
      AND   s.Status IN (N'OutForDelivery', N'AtDestinationHub', N'PickedUp')
    ORDER BY s.ReceiverPincode, s.Id;
END
GO

/* Submit proof of delivery + mark Delivered. Multi-table:
   ProofOfDelivery + Shipments status + TrackingEvent (+ optional COD collect). */
-- @ScopeBranchId / @RiderScopeId enforce branch + rider-assignment ownership.
-- The proc is idempotent against double-submission: it only delivers a shipment
-- that is currently OutForDelivery (a second call against an already-Delivered
-- shipment fails the transition check), so a retried offline-queue write can't
-- create a duplicate delivery or overwrite the collected COD amount.
CREATE OR ALTER PROCEDURE dbo.usp_Pod_Submit
    @ShipmentId     INT,
    @Type           NVARCHAR(20),         -- Photo | OTP | Signature
    @PhotoUrl       NVARCHAR(500) = NULL,
    @Otp            NVARCHAR(10)  = NULL,
    @RiderId        INT,
    @Latitude       DECIMAL(9,6)  = NULL,
    @Longitude      DECIMAL(9,6)  = NULL,
    @CodCollected   DECIMAL(18,2) = NULL, -- when COD shipment
    @Remarks        NVARCHAR(500) = NULL,
    @ScopeBranchId  INT = NULL,
    @RiderScopeId   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;

        DECLARE @Current NVARCHAR(20), @PaymentMode NVARCHAR(10),
                @AssignedRider INT, @OwnerBranchOk BIT = 0;
        SELECT @Current = Status, @PaymentMode = PaymentMode,
               @AssignedRider = AssignedRiderId,
               @OwnerBranchOk = CASE WHEN @ScopeBranchId IS NULL
                                       OR OriginBranchId  = @ScopeBranchId
                                       OR DestBranchId    = @ScopeBranchId
                                       OR CurrentBranchId = @ScopeBranchId
                                     THEN 1 ELSE 0 END
        FROM dbo.Shipments WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @ShipmentId;

        IF @Current IS NULL
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50030, 'Shipment not found.', 1;
        END

        IF @OwnerBranchOk = 0
           OR (@RiderScopeId IS NOT NULL AND (@AssignedRider IS NULL OR @AssignedRider <> @RiderScopeId))
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50032, 'Not authorized for this shipment.', 1;
        END

        -- Only an OutForDelivery shipment can be delivered. This rejects a
        -- replayed POD against an already-Delivered (or otherwise non-OFD) shipment.
        IF dbo.fn_IsValidStatusTransition(@Current, N'Delivered') = 0
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50033, 'Shipment is not out for delivery (already delivered or invalid state).', 1;
        END

        -- A COD shipment must collect its cash at delivery time.
        IF @PaymentMode = N'COD' AND @CodCollected IS NULL
        BEGIN
            ROLLBACK TRAN;
            ;THROW 50034, 'COD shipment requires the collected amount at delivery.', 1;
        END

        -- For OTP delivery, verify supplied OTP matches the latest unexpired one issued.
        IF @Type = N'OTP'
        BEGIN
            DECLARE @issued NVARCHAR(10) =
                (SELECT TOP (1) Otp FROM dbo.ProofOfDelivery
                 WHERE ShipmentId = @ShipmentId AND Type = N'OTP' AND Otp IS NOT NULL
                   AND (ExpiresAt IS NULL OR ExpiresAt > SYSUTCDATETIME())
                 ORDER BY Id DESC);
            IF @issued IS NULL OR @issued <> @Otp
            BEGIN
                ROLLBACK TRAN;
                ;THROW 50031, 'OTP verification failed.', 1;
            END
        END

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
-- The OTP is single-use by recency and expires after @ValidMinutes (default 15).
CREATE OR ALTER PROCEDURE dbo.usp_Pod_IssueOtp
    @ShipmentId   INT,
    @Otp          NVARCHAR(10),
    @ValidMinutes INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ExpiresAt DATETIME2(3) = DATEADD(MINUTE, @ValidMinutes, SYSUTCDATETIME());
    INSERT INTO dbo.ProofOfDelivery (ShipmentId, Type, Otp, ExpiresAt)
    VALUES (@ShipmentId, N'OTP', @Otp, @ExpiresAt);
    SELECT @ShipmentId AS ShipmentId, @ExpiresAt AS ExpiresAt;  -- OTP itself is NOT echoed
END
GO

/* ==========================================================================
   COD
   ========================================================================== */

-- Record collected amount (used when COD is collected separately from POD).
CREATE OR ALTER PROCEDURE dbo.usp_Cod_RecordCollection
    @ShipmentId      INT,
    @RiderId         INT,
    @AmountCollected DECIMAL(18,2),
    @ScopeBranchId   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @AmountCollected < 0
    BEGIN
        ;THROW 50040, 'Collected amount cannot be negative.', 1;
    END

    -- The COD row must exist (i.e. the shipment is COD) and be within the caller's branch scope.
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.CodTransactions c
        JOIN dbo.Shipments s ON s.Id = c.ShipmentId
        WHERE c.ShipmentId = @ShipmentId
          AND (@ScopeBranchId IS NULL
               OR s.OriginBranchId  = @ScopeBranchId
               OR s.DestBranchId    = @ScopeBranchId
               OR s.CurrentBranchId = @ScopeBranchId))
    BEGIN
        ;THROW 50041, 'COD record not found for this shipment (or not in scope).', 1;
    END

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
    @ShipmentId    INT,
    @ScopeBranchId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Must exist, be in scope, and have actually been collected before it can be deposited.
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.CodTransactions c
        JOIN dbo.Shipments s ON s.Id = c.ShipmentId
        WHERE c.ShipmentId = @ShipmentId
          AND (@ScopeBranchId IS NULL
               OR s.OriginBranchId  = @ScopeBranchId
               OR s.DestBranchId    = @ScopeBranchId
               OR s.CurrentBranchId = @ScopeBranchId))
    BEGIN
        ;THROW 50042, 'COD record not found for this shipment (or not in scope).', 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.CodTransactions
                   WHERE ShipmentId = @ShipmentId AND CollectedAt IS NOT NULL)
    BEGIN
        ;THROW 50043, 'Cannot mark COD deposited before it has been collected.', 1;
    END

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
    -- Outstanding = cash the rider has collected but not yet deposited to the
    -- branch (the figure this reconciliation exists to surface), i.e.
    -- Collected - Deposited. The window is on CollectedAt because these are
    -- collected funds being reconciled against deposits.
    SELECT  u.Id AS RiderId, u.Name AS RiderName, u.BranchId,
            COUNT(c.Id)                                   AS CodShipments,
            SUM(c.AmountExpected)                         AS TotalExpected,
            SUM(c.AmountCollected)                        AS TotalCollected,
            SUM(CASE WHEN c.Deposited = 1 THEN c.AmountCollected ELSE 0 END) AS TotalDeposited,
            SUM(c.AmountCollected)
              - SUM(CASE WHEN c.Deposited = 1 THEN c.AmountCollected ELSE 0 END) AS Outstanding
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
    -- Outstanding = collected-but-not-yet-deposited cash for the branch.
    SELECT  b.Id AS BranchId, b.Code AS BranchCode, b.Name AS BranchName,
            COUNT(c.Id)                                   AS CodShipments,
            SUM(c.AmountExpected)                         AS TotalExpected,
            SUM(c.AmountCollected)                        AS TotalCollected,
            SUM(CASE WHEN c.Deposited = 1 THEN c.AmountCollected ELSE 0 END) AS TotalDeposited,
            SUM(c.AmountCollected)
              - SUM(CASE WHEN c.Deposited = 1 THEN c.AmountCollected ELSE 0 END) AS Outstanding
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
