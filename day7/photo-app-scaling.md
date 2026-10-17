# SnapShare: Photo-App Scaling Plan

## 1. Assumptions and Daily Active Users

SnapShare is a photo-sharing application where users upload photos and scroll through a feed containing photos from people they follow.

The following assumptions are used:

* Registered users: 10,000,000.
* Daily active users: 10% of registered users.
* Each daily active user uploads one photo per day.
* Each daily active user views 50 feed pages per day.
* Each original photo has an average size of 2 MB.
* Each photo has one thumbnail with an average size of 50 KB.
* Peak traffic is estimated as 5 times the average traffic.
* Uploads and feed views are distributed across 24 hours for average-rate calculations.
* Each day has 86,400 seconds.
* One year has 365 days.
* Decimal storage units are used: 1 MB = 1,000 KB and 1 TB = 1,000,000 MB.
* All uploaded originals and thumbnails are retained throughout the year.
* Storage estimates exclude database records, backups, replication copies, and other operational overhead.

### Daily Active Users Calculation

Daily active users = Registered users × Daily active percentage

Daily active users = 10,000,000 × 0.10

**Daily active users = 1,000,000 users.**

## 2. Traffic and Storage Estimates

### A. Photo Uploads Per Second

Each daily active user uploads one photo per day.

Daily uploads = 1,000,000 × 1

Daily uploads = 1,000,000 photos per day.

Average uploads per second = Daily uploads ÷ Seconds per day

Average uploads per second = 1,000,000 ÷ 86,400

**Average uploads per second ≈ 11.57.**

Peak uploads per second = Average uploads per second × 5

Peak uploads per second = 11.57 × 5

**Peak uploads per second ≈ 57.87.**

### B. Feed Views Per Second

Each daily active user views 50 feed pages per day.

Daily feed views = 1,000,000 × 50

Daily feed views = 50,000,000 feed pages per day.

Average feed views per second = Daily feed views ÷ Seconds per day

Average feed views per second = 50,000,000 ÷ 86,400

**Average feed views per second ≈ 578.70.**

Peak feed views per second = Average feed views per second × 5

Peak feed views per second = 578.70 × 5

**Peak feed views per second ≈ 2,893.52.**

These peak values represent planning estimates, not guaranteed maximum traffic. Actual peaks may be higher or lower.

### C. Photo Storage Per Year

Each photo has two stored files:

* Original photo: 2 MB.
* Thumbnail: 50 KB = 0.05 MB.

Total storage per photo = 2 MB + 0.05 MB

Total storage per photo = 2.05 MB.

Daily storage growth = 1,000,000 × 2.05 MB

Daily storage growth = 2,050,000 MB = 2.05 TB.

Yearly storage growth = 2.05 TB × 365

**Yearly storage growth = 748.25 TB.**

This is the estimated amount of new storage required for original photos and thumbnails over one year, excluding backups, database records, replication copies, and other overhead.

### Summary Table

| Measurement                     | Estimated value |
| ------------------------------- | --------------: |
| Daily active users              |       1,000,000 |
| Daily photo uploads             |       1,000,000 |
| Average uploads per second      |           11.57 |
| Peak uploads per second (5×)    |           57.87 |
| Daily feed views                |      50,000,000 |
| Average feed views per second   |          578.70 |
| Peak feed views per second (5×) |        2,893.52 |
| Storage growth per year         |       748.25 TB |

## 3. Is SnapShare Read-Heavy or Write-Heavy?

SnapShare is a **read-heavy system** because users view feed pages much more frequently than they upload photos.

Daily feed views = 50,000,000.

Daily photo uploads = 1,000,000.

Feed views per upload = 50,000,000 ÷ 1,000,000 = 50.

Therefore, there are approximately 50 feed views for every photo upload.

This means the design should prioritize fast feed responses and efficient image delivery. A cache can reduce repeated database queries, a database read replica can handle suitable read queries, and a CDN can deliver images without sending every image request through the application servers.

The application must still support reliable photo uploads, but read performance is the primary scaling concern.

## 4. Why Photos Should Not Be Stored Inside the Database

Original photos and thumbnails should be stored in **object storage**, such as Amazon S3 or another compatible object-storage service.

Photos are large binary files. Storing millions of them directly inside the application database can increase database size, backup time, storage costs, and the workload required for database maintenance.

Object storage is designed to store large files at scale and can integrate with a CDN for efficient delivery.

The database should instead store structured metadata, such as the photo ID, owner ID, object-storage key, upload timestamp, thumbnail key, and processing status.

This separation allows the database to manage relationships and metadata while object storage manages the image files.

## 5. Architecture Diagram

```text
                          USERS
                            |
                            v
                          [ CDN ]
                            |
                            v
                     [ Load Balancer ]
                            |
                 +----------+----------+
                 |          |          |
                 v          v          v
             [ App 1 ]  [ App 2 ]  [ App 3 ]
                 |          |          |
                 +----------+----------+
                            |
                +-----------+-----------+
                |           |           |
                v           v           v
             [ Cache ] [ Primary DB ] [ Object Storage ]
                            |             ^       |
                            v             |       |
                     [ Read Replica ]     |       |
                                          |       |
                                   [ Thumbnail    |
                                      Worker ]    |
                                          ^       |
                                          |       |
                                   [ Upload Queue ]
                                                  |
                                       Original and
                                       thumbnail files
```

The CDN delivers cached images, the load balancer distributes incoming requests, and multiple application servers handle application logic.

The cache and database read replica reduce pressure on the primary database. Object storage keeps image files separate from database records.

After an original photo is stored, a job enters the upload queue. A thumbnail worker processes the job and stores the generated thumbnail in object storage.

## 6. Components and the Problems They Solve

1. **CDN:** Caches and delivers photos and thumbnails close to users, reducing image-loading latency and requests reaching the origin.

2. **Load Balancer:** Distributes incoming requests across multiple application servers, preventing one server from becoming a bottleneck and allowing additional servers to be added.

3. **Application Servers:** Handle authentication, upload validation, feed requests, and communication with the cache, database, object storage, and queue.

4. **Cache:** Keeps frequently requested feed data and other reusable results in fast memory, reducing repeated database queries and improving response times.

5. **Primary Database:** Stores structured data such as user accounts, follow relationships, photo metadata, and other application records while handling persistent writes.

6. **Database Read Replica:** Copies data from the primary database and serves suitable read queries, reducing read pressure on the primary database.

7. **Object Storage:** Stores original photos and generated thumbnails as files, allowing image storage to scale independently of the database.

8. **Upload Queue:** Holds thumbnail-generation jobs until workers can process them, absorbing temporary spikes and separating background processing from the upload request.

9. **Thumbnail Worker:** Processes queued jobs, creates smaller image versions, and saves the thumbnails to object storage for efficient delivery.

## 7. Photo Upload Flow

1. A user selects a photo and submits an upload request.
2. The load balancer routes the request to an available application server.
3. The application server authenticates the user, validates the request, and checks the file against upload rules.
4. The application arranges for the original photo to be uploaded to object storage. It may provide a secure, time-limited upload URL so the client can upload the file directly.
5. After the original photo is successfully stored, the application saves its metadata in the primary database, including the owner ID, storage key, upload time, and processing status.
6. The application places a thumbnail-generation job on the upload queue.
7. The application confirms the successful upload without making the user wait for thumbnail generation to finish.
8. A background thumbnail worker retrieves the job from the queue.
9. The worker reads the original photo from object storage and generates a smaller thumbnail targeting an average size of 50 KB.
10. The worker stores the thumbnail in object storage and updates the processing status or thumbnail metadata in the database.
11. When users request the photo or thumbnail, the CDN delivers the image from its cache or retrieves it from the configured origin.

If thumbnail generation fails, the system can retry the job. Until the thumbnail is ready, the application can show a processing indicator or use the original photo as a temporary fallback.

## 8. Scaling Trade-Offs

### Trade-Off 1: Caching Versus Data Freshness

Caching feed data reduces database load and improves response times. However, cached feeds may not immediately reflect a newly uploaded photo or a changed follow relationship.

SnapShare can use cache expiration times and targeted invalidation to balance speed with freshness.

### Trade-Off 2: Asynchronous Processing Versus Immediate Thumbnail Availability

A queue and background worker allow uploads to be accepted without waiting for thumbnail generation. However, thumbnails may not be available immediately.

SnapShare can display a processing indicator or temporarily show the original photo until the thumbnail is ready.

### Trade-Off 3: Read Replicas Versus Read Consistency

A read replica allows more feed queries to be handled without overloading the primary database. However, replication delay can cause recently written information to be temporarily missing from replica reads.

SnapShare can tolerate small delays for ordinary feed browsing while directing critical reads to the primary database when necessary.

### Trade-Off 4: Original Image Quality Versus Storage and Bandwidth Costs

Retaining original photos preserves full image quality but requires significant storage and bandwidth. Smaller thumbnails make feed browsing more efficient but require additional processing and storage.

SnapShare can retain originals for full-size viewing and use thumbnails for feed previews.

## 9. Conclusion

SnapShare has approximately 1,000,000 daily active users. It handles an estimated average of 11.57 photo uploads and 578.70 feed views per second. Using a 5× peak multiplier, the estimated peak rates are 57.87 uploads and 2,893.52 feed views per second.

At the stated upload rate, original photos and thumbnails require approximately 748.25 TB of additional storage per year.

SnapShare is read-heavy, so the design prioritizes efficient feed delivery through a CDN, cache, and database read replica. Object storage keeps large image files separate from structured database records, while a queue and background worker handle thumbnail generation asynchronously.

The system should be monitored for peak traffic, response times, cache hit rate, database load, queue backlog, thumbnail failures, and storage growth so that capacity can be increased as usage grows.
