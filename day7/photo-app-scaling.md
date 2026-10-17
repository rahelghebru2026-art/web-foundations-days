# SnapShare Scaling Plan

## 1. Assumptions and Daily Active Users (DAU)
- **Total Registered Users:** 10,000,000
- **Activity Rate:** 10% active per day
- **Daily Active Users (DAU):** 10,000,000 × 0.10 = **1,000,000 DAU**
- **User Activity Metrics:** Each active user uploads 1 photo per day and views 50 feed pages per day.
- **Media File Sizes:** Average photo = 2 MB; average thumbnail = 50 KB.
- **Time Conversion:** 1 day = 86,400 seconds. Peak traffic multiplier = 5× average traffic.

## 2. Traffic and Storage Calculations
- **Uploads per Second (Writes):**
  - *Average:* 1,000,000 uploads ÷ 86,400 seconds $\approx$ **11.57 writes/sec** (~12 writes/sec)
  - *Peak (5×):* 11.57 × 5 $\approx$ **57.85 writes/sec** (~58 writes/sec)
- **Feed Views per Second (Reads):**
  - Total daily views: 1,000,000 users × 50 views = 50,000,000 feed views/day
  - *Average:* 50,000,000 views ÷ 86,400 seconds $\approx$ **578.70 reads/sec** (~579 reads/sec)
  - *Peak (5×):* 578.70 × 5 $\approx$ **2,893.50 reads/sec** (~2,894 reads/sec)
- **Photo Storage per Year:**
  - Raw photos: 1,000,000 uploads/day × 2 MB = 2,000,000 MB/day (2 TB/day)
  - Thumbnails: 1,000,000 thumbnails/day × 50 KB = 50,000 MB/day (0.05 TB/day)
  - Total daily storage: 2.05 TB/day
  - Total annual storage: 2.05 TB/day × 365 days $\approx$ **748.25 TB/year** (~750 TB/year)

## 3. System Traffic Profile: Read-Heavy vs. Write-Heavy
- **Profile:** The system is overwhelmingly **read-heavy**, operating at roughly a 50:1 read-to-write ratio (~579 reads/sec vs. ~12 writes/sec on average).
- **Design Implications:** Because reads vastly outnumber writes, the architecture must prioritize read scalability. This requires deploying read replicas for the database, implementing an in-memory cache (Redis) for hot metadata/feeds, and utilizing a Content Delivery Network (CDN) to serve static image assets globally with minimal latency.

## 4. Why Photos Should Not Be Stored Inside the Database
Relational databases are optimized for structured data, quick indexing, and ACID-compliant transactional metadata (like user accounts, relationships, and timestamps). Storing massive binary image files (blobs) directly inside a database causes severe performance degradation, bloats database size, drastically slows down backups and migrations, and overwhelms CPU and memory resources. Instead, raw photo binaries must be stored in specialized **Object Storage** (such as Amazon S3), while only lightweight string URLs pointing to those files are saved in the database.

## 5. Architecture Diagram

```text
[ Mobile / Web Clients ]
         │
         ▼
    [ CDN ] (Caches images and thumbnails globally)
         │
         ▼
[ Load Balancer ] (Distributes traffic across servers)
         │
         ├────────────────────────┐
         ▼                        ▼
  [ App Server 1 ]         [ App Server 2 ]
         │                        │
         ├──────────┬─────────────┼──────────────┐
         ▼          ▼             ▼              ▼
   [ Redis Cache ] [ Primary DB ] [ Read Replica ] [ Message Queue ]
                           ▲             │               │
                           │             ▼               ▼
                           └─────── [ Object Storage ] [ Background Worker ]
                                     (S3 / Blob Storage)  (Thumbnail Gen)