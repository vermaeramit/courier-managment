/* ============================================================================
   Courier Management System (MVP)
   03_seed.sql  -  sample data for local testing. Idempotent.

   Seed accounts (all share password:  Passw0rd!):
     admin@courier.test     -> Admin (HQ, no branch)
     manager.roh@courier.test -> BranchManager (ROH / Rohini)
     rider.roh@courier.test   -> Rider (ROH)

   The PasswordHash values below are produced by ASP.NET Core's
   Microsoft.AspNetCore.Identity.PasswordHasher (PBKDF2, format marker 0x01)
   for the plaintext "Passw0rd!". If you change the hashing settings, re-seed
   using the /api/auth/dev-hash helper noted in the README, or just create
   users through the API.
   ============================================================================ */

USE CourierMvp;
GO
SET NOCOUNT ON;
GO

/* PasswordHash below is a genuine ASP.NET Core Identity (PBKDF2 / V3) hash for the
   plaintext "Passw0rd!". The hash is self-describing — VerifyHashedPassword reads
   the PRF, iteration count and salt from the value itself — so it verifies
   regardless of the API's current hasher defaults. To mint a fresh one, call the
   dev helper:  GET /api/auth/dev-hash?password=YourPass  (Development only). */
DECLARE @Pwd NVARCHAR(500) =
    N'AQAAAAEAAYagAAAAEAEjRWeJq83vASNFZ4mrze/OS/WnAXnU+wiFlb6G5qkvZXDBA5rETe8+bQiE6IMDfQ==';

/* -------------------- Branches -------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Branches WHERE Code = N'ROH')
    INSERT INTO dbo.Branches (Code, Name, City, Pincode, IsActive)
    VALUES (N'ROH', N'Rohini Hub', N'Delhi', N'110085', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Branches WHERE Code = N'BLR')
    INSERT INTO dbo.Branches (Code, Name, City, Pincode, IsActive)
    VALUES (N'BLR', N'Koramangala Hub', N'Bengaluru', N'560034', 1);
GO

DECLARE @RohId INT = (SELECT Id FROM dbo.Branches WHERE Code = N'ROH');
DECLARE @BlrId INT = (SELECT Id FROM dbo.Branches WHERE Code = N'BLR');
DECLARE @Pwd NVARCHAR(500) =   -- PBKDF2 hash of "Passw0rd!" (see note at top)
    N'AQAAAAEAAYagAAAAEAEjRWeJq83vASNFZ4mrze/OS/WnAXnU+wiFlb6G5qkvZXDBA5rETe8+bQiE6IMDfQ==';

/* -------------------- Users -------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'admin@courier.test')
    INSERT INTO dbo.Users (BranchId, Name, Role, Phone, Email, PasswordHash, Status)
    VALUES (NULL, N'HQ Admin', N'Admin', N'9000000001', N'admin@courier.test', @Pwd, N'Active');

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'manager.roh@courier.test')
    INSERT INTO dbo.Users (BranchId, Name, Role, Phone, Email, PasswordHash, Status)
    VALUES (@RohId, N'Rohini Manager', N'BranchManager', N'9000000002', N'manager.roh@courier.test', @Pwd, N'Active');

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'rider.roh@courier.test')
    INSERT INTO dbo.Users (BranchId, Name, Role, Phone, Email, PasswordHash, Status)
    VALUES (@RohId, N'Rohini Rider', N'Rider', N'9000000003', N'rider.roh@courier.test', @Pwd, N'Active');

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'manager.blr@courier.test')
    INSERT INTO dbo.Users (BranchId, Name, Role, Phone, Email, PasswordHash, Status)
    VALUES (@BlrId, N'Bengaluru Manager', N'BranchManager', N'9000000004', N'manager.blr@courier.test', @Pwd, N'Active');
GO

/* Wire branch managers back to Branches.ManagerId */
UPDATE b SET ManagerId = u.Id
FROM dbo.Branches b
JOIN dbo.Users u ON u.Email = N'manager.roh@courier.test'
WHERE b.Code = N'ROH';

UPDATE b SET ManagerId = u.Id
FROM dbo.Branches b
JOIN dbo.Users u ON u.Email = N'manager.blr@courier.test'
WHERE b.Code = N'BLR';
GO

/* -------------------- Serviceable pincodes -------------------- */
DECLARE @RohId INT = (SELECT Id FROM dbo.Branches WHERE Code = N'ROH');
DECLARE @BlrId INT = (SELECT Id FROM dbo.Branches WHERE Code = N'BLR');

MERGE dbo.ServiceablePincodes AS t
USING (VALUES
    (N'110085', @RohId), (N'110086', @RohId), (N'110042', @RohId),
    (N'560034', @BlrId), (N'560095', @BlrId), (N'560068', @BlrId)
) AS s(Pincode, BranchId)
ON t.Pincode = s.Pincode AND t.BranchId = s.BranchId
WHEN NOT MATCHED THEN
    INSERT (Pincode, BranchId, IsServiceable) VALUES (s.Pincode, s.BranchId, 1);
GO

PRINT 'Seed data inserted.';
GO
