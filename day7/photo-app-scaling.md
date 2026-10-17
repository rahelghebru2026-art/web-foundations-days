# SnapShare Scaling Plan

## 1. Assumptions
- **Total Registered Users:** 10,000,000
- **Daily Active Rate:** 10% of registered users
- **Daily Active Users (DAU):** 1,000,000 active users
- **User Activity:** Each active user uploads 1 photo per day and views 50 feed pages per day.
- **File Sizes:** Average raw photo size = 2 MB; generated thumbnail size = 50 KB.
- **Time Conversion:** 1 day = 86,400 seconds.

## 2. Traffic and Storage Estimates
- **Uploads per Second (Writes):** 
  - 1,000,000 uploads per day divided by 86,400 seconds equals approximately **11.57 writes/sec** (~12 writes/sec).
- **Feed Views per Second (Reads):** 
  - 1,000,000 active users multiplied by 50 views equals 50,000,000 total feed views per day. Divided by 86,400 seconds equals approximately **578.70 reads/sec** (~579 reads/sec).
- **Storage per Year:** 
  - Raw photos: 1,000,000 uploads/day * 2 MB = 2,000,000 MB/day (2 TB/day).
  - Thumbnails: 1,000,000 thumbnails/day * 50 KB = 50,000 MB/day (0.05 TB/day).
  - Total daily storage: 2.05 TB/day.
  - Annual storage: 2.05 TB/day * 365 days = **748.25 TB/year** (~750 TB/year).

## 3. System Workload Profile
- **Profile:** The system is overwhelmingly **read-heavy** (operating at roughly a 50:1 read-to-write ratio with ~579 reads/sec vs. ~12 writes/sec).
- **Design Impact:** Because reads vastly outnumber writes, the architecture must focus heavily on read scaling techniques, such as deploying database read replicas, implementing caching layers for feeds, and using a CDN to deliver media globally with minimal latency.

## 4. Architecture Diagram

```text
[ Mobile / Web Clients ]
         │
         ▼
    [ CDN ] (Caches static assets and thumbnails globally)
         │
         ▼
[ Load Balancer ] (Distributes incoming requests evenly)
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
                                     (S3 Blob Store)   (Thumbnail Generator)