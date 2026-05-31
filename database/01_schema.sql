/* ============================================================================
   Courier Management System (MVP)
   01_schema.sql  -  Tables, sequence, indexes, constraints.
   Target: Microsoft SQL Server 2019+
   Idempotent: safe to re-run (drops are guarded with IF EXISTS).
   All money is DECIMAL. All timestamps are UTC (SYSUTCDATETIME()).
   ============================================================================ */

IF DB_ID(N'CourierMvp') IS NULL
BEGIN
    CREATE DATABASE CourierMvp;
END
GO

USE CourierMvp;
GO

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------------
   Drop in reverse dependency order so the script can be re-run cleanly.
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ProofOfDelivery', N'U')   IS NOT NULL DROP TABLE dbo.ProofOfDelivery;
IF OBJECT_ID(N'dbo.CodTransactions', N'U')   IS NOT NULL DROP TABLE dbo.CodTransactions;
IF OBJECT_ID(N'dbo.TrackingEvents', N'U')    IS NOT NULL DROP TABLE dbo.TrackingEvents;
IF OBJECT_ID(N'dbo.ServiceablePincodes', N'U') IS NOT NULL DROP TABLE dbo.ServiceablePincodes;
IF OBJECT_ID(N'dbo.Shipments', N'U')         IS NOT NULL DROP TABLE dbo.Shipments;
IF OBJECT_ID(N'dbo.Users', N'U')             IS NOT NULL DROP TABLE dbo.Users;
IF OBJECT_ID(N'dbo.Branches', N'U')          IS NOT NULL DROP TABLE dbo.Branches;
GO

IF EXISTS (SELECT 1 FROM sys.sequences WHERE name = N'Seq_ShipmentNumber')
    DROP SEQUENCE dbo.Seq_ShipmentNumber;
GO

/* ---------------------------------------------------------------------------
   Sequence used to generate the numeric portion of a TrackingId.
   TrackingId format: <OriginBranchCode><8-digit zero-padded sequence>
   --------------------------------------------------------------------------- */
CREATE SEQUENCE dbo.Seq_ShipmentNumber
    AS BIGINT
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    NO CYCLE
    CACHE 50;
GO

/* ---------------------------------------------------------------------------
   Branches
   --------------------------------------------------------------------------- */
CREATE TABLE dbo.Branches
(
    Id          INT IDENTITY(1,1)   NOT NULL CONSTRAINT PK_Branches PRIMARY KEY,
    Code        NVARCHAR(10)        NOT NULL,   -- used as tracking-ID prefix, e.g. 'ROH'
    Name        NVARCHAR(150)       NOT NULL,
    City        NVARCHAR(100)       NOT NULL,
    Pincode     NVARCHAR(10)        NOT NULL,
    ManagerId   INT                 NULL,       -- FK added after Users exists
    IsActive    BIT                 NOT NULL CONSTRAINT DF_Branches_IsActive DEFAULT (1),
    CreatedAt   DATETIME2(3)        NOT NULL CONSTRAINT DF_Branches_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_Branches_Code UNIQUE (Code)
);
GO

/* ---------------------------------------------------------------------------
   Users
   Role: Admin | BranchManager | Rider
   --------------------------------------------------------------------------- */
CREATE TABLE dbo.Users
(
    Id           INT IDENTITY(1,1)  NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    BranchId     INT                NULL,       -- Admin (HQ) may have NULL branch
    Name         NVARCHAR(150)      NOT NULL,
    Role         NVARCHAR(20)       NOT NULL,
    Phone        NVARCHAR(20)       NULL,
    Email        NVARCHAR(150)      NOT NULL,
    PasswordHash NVARCHAR(500)      NOT NULL,   -- ASP.NET Core PasswordHasher (PBKDF2) format
    Status       NVARCHAR(20)       NOT NULL CONSTRAINT DF_Users_Status DEFAULT (N'Active'),
    CreatedAt    DATETIME2(3)       NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Role CHECK (Role IN (N'Admin', N'BranchManager', N'Rider')),
    CONSTRAINT FK_Users_Branch FOREIGN KEY (BranchId) REFERENCES dbo.Branches(Id)
);
GO

-- Now that Users exists, wire Branches.ManagerId -> Users.Id
ALTER TABLE dbo.Branches
    ADD CONSTRAINT FK_Branches_Manager FOREIGN KEY (ManagerId) REFERENCES dbo.Users(Id);
GO

/* ---------------------------------------------------------------------------
   Shipments
   Status lifecycle:
     Booked -> PickedUp -> AtOriginHub -> InTransit -> AtDestinationHub
            -> OutForDelivery -> Delivered
     terminal: Failed, RTO
   --------------------------------------------------------------------------- */
CREATE TABLE dbo.Shipments
(
    Id              INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Shipments PRIMARY KEY,
    TrackingId      NVARCHAR(30)      NOT NULL,
    InvoiceNumber   NVARCHAR(30)      NULL,    -- GST-style invoice number
    BarcodeValue    NVARCHAR(50)      NULL,    -- value encoded by barcode/QR (== TrackingId)
    OriginBranchId  INT               NOT NULL,
    DestBranchId    INT               NOT NULL,
    CurrentBranchId INT               NULL,    -- branch currently holding the parcel (handoff)

    SenderName      NVARCHAR(150)     NOT NULL,
    SenderPhone     NVARCHAR(20)      NOT NULL,
    SenderAddress   NVARCHAR(400)     NOT NULL,
    SenderPincode   NVARCHAR(10)      NOT NULL,

    ReceiverName    NVARCHAR(150)     NOT NULL,
    ReceiverPhone   NVARCHAR(20)      NOT NULL,
    ReceiverAddress NVARCHAR(400)     NOT NULL,
    ReceiverPincode NVARCHAR(10)      NOT NULL,

    Weight          DECIMAL(9,3)      NOT NULL CONSTRAINT DF_Shipments_Weight DEFAULT (0),
    ServiceType     NVARCHAR(20)      NOT NULL,
    PaymentMode     NVARCHAR(10)      NOT NULL,
    CodAmount       DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Shipments_Cod DEFAULT (0),

    Status          NVARCHAR(20)      NOT NULL CONSTRAINT DF_Shipments_Status DEFAULT (N'Booked'),
    AssignedRiderId INT               NULL,
    CreatedBy       INT               NOT NULL,
    CreatedAt       DATETIME2(3)      NOT NULL CONSTRAINT DF_Shipments_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       DATETIME2(3)      NOT NULL CONSTRAINT DF_Shipments_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT UQ_Shipments_TrackingId UNIQUE (TrackingId),
    CONSTRAINT CK_Shipments_ServiceType CHECK (ServiceType IN (N'Standard', N'Express', N'SameDay')),
    CONSTRAINT CK_Shipments_PaymentMode CHECK (PaymentMode IN (N'Prepaid', N'COD')),
    CONSTRAINT CK_Shipments_Status CHECK (Status IN
        (N'Booked', N'PickedUp', N'AtOriginHub', N'InTransit', N'AtDestinationHub',
         N'OutForDelivery', N'Delivered', N'Failed', N'RTO')),
    CONSTRAINT FK_Shipments_Origin FOREIGN KEY (OriginBranchId) REFERENCES dbo.Branches(Id),
    CONSTRAINT FK_Shipments_Dest   FOREIGN KEY (DestBranchId)   REFERENCES dbo.Branches(Id),
    CONSTRAINT FK_Shipments_Current FOREIGN KEY (CurrentBranchId) REFERENCES dbo.Branches(Id),
    CONSTRAINT FK_Shipments_Rider  FOREIGN KEY (AssignedRiderId) REFERENCES dbo.Users(Id),
    CONSTRAINT FK_Shipments_CreatedBy FOREIGN KEY (CreatedBy)   REFERENCES dbo.Users(Id)
);
GO

CREATE INDEX IX_Shipments_OriginBranch ON dbo.Shipments (OriginBranchId, Status);
CREATE INDEX IX_Shipments_DestBranch   ON dbo.Shipments (DestBranchId, Status);
CREATE INDEX IX_Shipments_Rider        ON dbo.Shipments (AssignedRiderId, Status);
CREATE INDEX IX_Shipments_CreatedAt    ON dbo.Shipments (CreatedAt);
GO

/* ---------------------------------------------------------------------------
   TrackingEvents  -  append-only audit trail powering the public tracking link.
   --------------------------------------------------------------------------- */
CREATE TABLE dbo.TrackingEvents
(
    Id          BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TrackingEvents PRIMARY KEY,
    ShipmentId  INT                  NOT NULL,
    Status      NVARCHAR(20)         NOT NULL,
    BranchId    INT                  NULL,
    RiderId     INT                  NULL,
    Latitude    DECIMAL(9,6)         NULL,
    Longitude   DECIMAL(9,6)         NULL,
    Remarks     NVARCHAR(500)        NULL,
    CreatedAt   DATETIME2(3)         NOT NULL CONSTRAINT DF_TrackingEvents_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT FK_TrackingEvents_Shipment FOREIGN KEY (ShipmentId) REFERENCES dbo.Shipments(Id),
    CONSTRAINT FK_TrackingEvents_Branch   FOREIGN KEY (BranchId)   REFERENCES dbo.Branches(Id),
    CONSTRAINT FK_TrackingEvents_Rider    FOREIGN KEY (RiderId)    REFERENCES dbo.Users(Id)
);
GO

CREATE INDEX IX_TrackingEvents_Shipment ON dbo.TrackingEvents (ShipmentId, CreatedAt);
GO

/* ---------------------------------------------------------------------------
   CodTransactions  -  one row per COD shipment; collected/deposited tracked here.
   --------------------------------------------------------------------------- */
CREATE TABLE dbo.CodTransactions
(
    Id             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CodTransactions PRIMARY KEY,
    ShipmentId     INT               NOT NULL,
    RiderId        INT               NULL,
    AmountExpected DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Cod_Expected DEFAULT (0),
    AmountCollected DECIMAL(18,2)    NOT NULL CONSTRAINT DF_Cod_Collected DEFAULT (0),
    Deposited      BIT               NOT NULL CONSTRAINT DF_Cod_Deposited DEFAULT (0),
    CollectedAt    DATETIME2(3)      NULL,
    DepositedAt    DATETIME2(3)      NULL,
    CONSTRAINT UQ_Cod_Shipment UNIQUE (ShipmentId),
    CONSTRAINT FK_Cod_Shipment FOREIGN KEY (ShipmentId) REFERENCES dbo.Shipments(Id),
    CONSTRAINT FK_Cod_Rider    FOREIGN KEY (RiderId)    REFERENCES dbo.Users(Id)
);
GO

CREATE INDEX IX_Cod_Rider ON dbo.CodTransactions (RiderId, CollectedAt);
GO

/* ---------------------------------------------------------------------------
   ProofOfDelivery  -  kept as its own table for clarity (Photo|OTP|Signature).
   --------------------------------------------------------------------------- */
CREATE TABLE dbo.ProofOfDelivery
(
    Id          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProofOfDelivery PRIMARY KEY,
    ShipmentId  INT               NOT NULL,
    Type        NVARCHAR(20)      NOT NULL,
    PhotoUrl    NVARCHAR(500)     NULL,
    Otp         NVARCHAR(10)      NULL,
    DeliveredAt DATETIME2(3)      NOT NULL CONSTRAINT DF_Pod_DeliveredAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT CK_Pod_Type CHECK (Type IN (N'Photo', N'OTP', N'Signature')),
    CONSTRAINT FK_Pod_Shipment FOREIGN KEY (ShipmentId) REFERENCES dbo.Shipments(Id)
);
GO

CREATE INDEX IX_Pod_Shipment ON dbo.ProofOfDelivery (ShipmentId);
GO

/* ---------------------------------------------------------------------------
   ServiceablePincodes  -  destination pincode validated against this before booking.
   --------------------------------------------------------------------------- */
CREATE TABLE dbo.ServiceablePincodes
(
    Id           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServiceablePincodes PRIMARY KEY,
    Pincode      NVARCHAR(10)      NOT NULL,
    BranchId     INT               NOT NULL,
    IsServiceable BIT              NOT NULL CONSTRAINT DF_Pincode_Serviceable DEFAULT (1),
    CONSTRAINT UQ_Pincode_Branch UNIQUE (Pincode, BranchId),
    CONSTRAINT FK_Pincode_Branch FOREIGN KEY (BranchId) REFERENCES dbo.Branches(Id)
);
GO

CREATE INDEX IX_Pincode_Lookup ON dbo.ServiceablePincodes (Pincode, IsServiceable);
GO

PRINT 'Schema created.';
GO
