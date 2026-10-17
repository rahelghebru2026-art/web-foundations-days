# SnapShare: Photo-App Scaling Plan

## 1. Assumptions

SnapShare is a photo-sharing application where users upload photos and view a feed containing photos from people they follow.

The following assumptions are used for this scaling plan:

* SnapShare has 10,000,000 registered users.
* 10% of registered users are active each day.
* Each daily active user uploads 1 photo per day.
* Each daily active user views 50 feed pages per day.
* Each original photo has an average size of 2 MB.
* Each photo also has one thumbnail with an average size of 50 KB.
* Each uploaded photo is stored for one year or longer.
* All daily active users are assumed to perform their uploads and feed views every day.
* Uploads and feed views are distributed across 24 hours for the average-rate calculations.
* Storage estimates use decimal units: 1 MB = 1,000 KB and 1 GB = 1,000 MB.
* The storage calculation includes original photos and thumbnails but excludes database records, backups, replication copies, and other operational overhead.

These are average estimates. Actual traffic may be higher during peak hours.

## 2. Traffic and Storage Estimates

### A. Daily Active Users

10,000,000 registered users × 10% active daily

Daily active users = 1,000,000 users.

### B. Photo Uploads Per Second

Each daily active user uploads 1 photo per day.

Daily uploads = 1,000,000 × 1

Daily uploads = 1,000,000 photos.

Average uploads per second = 1,000,000 ÷ 86,400

Average uploads per second ≈ 11.57 photos per second.

Therefore, SnapShare must handle approximately 12 photo uploads per second on average.

### C. Feed Views Per Second

Each daily active user views 50 feed pages per day.

Daily feed views = 1,000,000 × 50

Daily feed views = 50,000,000 feed pages.

Average feed views per second = 50,000,000 ÷ 86,400

Average feed views per second ≈ 578.70 feed pages per second.

Therefore, SnapShare must handle approximately 579 feed page requests per second on average.

### D. Storage Per Year

Each photo consists of:

* Original photo: 2 MB.
* Thumbnail: 50 KB = 0.05 MB.

Total storage per photo = 2 MB + 0.05 MB

Total storage per photo = 2.05 MB.

Daily storage growth:

1,000,000 photos × 2.05 MB = 2,050,000 MB per day.

This equals approximately 2.05 TB per day.

Yearly storage growth:

2,050,000 MB × 365 = 748,250,000 MB per year.

Therefore, yearly storage growth is approximately 748.25 TB, excluding database records, backups, replication copies, and other overhead.

This estimate assumes the application retains all uploaded photos and thumbnails for the entire year.

## 3. Is SnapShare Read-Heavy or Write-Heavy?

SnapShare is a read-heavy system because users view 50 feed pages per day but upload only 1 photo per day.

Daily feed views: 50,000,000.

Daily photo uploads: 1,000,000.

The ratio of feed views to photo uploads is 50:1.

This means feed requests occur approximately 50 times as often as photo uploads. Therefore, the architecture should prioritize fast feed delivery, caching, and efficient image delivery through a Content Delivery Network (CDN).

## 4. Proposed Architecture Diagram

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
              +------------+------------+
              |            |            |
              v            v            v
           [ Cache ]  [ Primary DB ] [ Object Storage ]
                          |               |
                          v               |
                    [ Read Replica ]      |
                                          |
                         [ Upload Queue ] |
                                |         |
                                v         |
                             [ Worker ]   |
                         Create Thumbnail|
                                |         |
                                +---------+
                                  Store
                               Thumbnail
```

The diagram shows the main components and their relationships. The application servers use the cache and database to serve feed requests, while the object storage holds original photos and generated thumbnails.

The load balancer distributes incoming requests across application servers. The upload queue and worker handle thumbnail generation asynchronously so that users do not need to wait for this processing to finish before an upload is accepted.

## 5. Components and the Problems They Solve

### 1. CDN (Content Delivery Network)

The CDN caches and delivers photos and thumbnails from locations close to users, reducing latency and lowering the amount of image traffic reaching the application servers.

### 2. Load Balancer

The load balancer distributes incoming requests across multiple application servers, preventing one server from becoming overloaded and allowing additional servers to be added as traffic grows.

### 3. Application Servers

The application servers handle user requests, authentication, photo-upload authorization, feed generation, and communication with the cache, database, object storage, and queue.

### 4. Cache

The cache stores frequently requested feed data, user information, and other reusable results in fast memory, reducing repeated database queries and improving response times.

### 5. Primary Database

The primary database stores structured application data such as user accounts, follow relationships, photo metadata, and feed-related records, while handling writes that must be persisted.

### 6. Database Read Replica

The read replica copies data from the primary database and serves suitable read queries, reducing read pressure on the primary database and improving the application's ability to handle frequent feed requests.

### 7. Object Storage

Object storage stores the original photo files and generated thumbnails separately from the database, providing scalable storage for large amounts of image data.

### 8. Upload Queue

The upload queue holds thumbnail-generation jobs until workers can process them, absorbing temporary traffic spikes and separating image processing from the user's upload request.

### 9. Thumbnail Worker

The thumbnail worker retrieves queued jobs, generates smaller versions of uploaded photos, and saves the thumbnails to object storage so they can be delivered efficiently through the CDN.

## 6. Step-by-Step Photo Upload Flow

1. A user selects a photo and submits an upload request to SnapShare.
2. The load balancer directs the request to an available application server.
3. The application server authenticates the user, validates the request, and checks that the photo meets the application's upload rules.
4. The application server arranges for the original photo to be stored in object storage. The application can upload the file directly to object storage using a secure, time-limited upload URL.
5. After the original photo is successfully stored, the application saves the photo's metadata, such as its owner, storage key, upload time, and processing status, in the primary database.
6. The application places a thumbnail-generation job on the upload queue.
7. The application confirms the upload to the user without waiting for thumbnail generation to finish.
8. A background worker retrieves the job from the queue and downloads or reads the original photo from object storage.
9. The worker generates a thumbnail with an average target size of 50 KB and saves it to object storage.
10. The worker updates the photo's processing status or metadata in the database.
11. The CDN can then cache and deliver the original photo and thumbnail when users request them.

If thumbnail generation fails, the job can be retried. The application should track processing status so that a photo whose thumbnail is not yet available can still be handled gracefully.

## 7. Feed Viewing Flow

1. A user opens SnapShare and requests their photo feed.
2. The load balancer directs the request to an available application server.
3. The application server checks the cache for reusable feed data.
4. If the required data is cached, the application returns the cached results.
5. If the data is not cached, the application queries the database read replica for suitable feed metadata and information about photos from followed users.
6. The application returns the feed data, including photo identifiers and image URLs, to the user.
7. The user's browser or mobile application requests the images through the CDN.
8. The CDN serves cached images when available. If an image is not cached, the CDN retrieves it from object storage or the configured image origin and caches it according to the caching policy.

This approach keeps most image delivery away from the application servers and reduces unnecessary database reads.

## 8. Scaling Trade-Offs

### Trade-Off 1: Caching Versus Data Freshness

Caching feed data improves response times and reduces database load. However, cached data may become outdated when a user uploads a new photo or follows someone new.

SnapShare can use short cache expiration times or targeted cache invalidation to balance performance with freshness.

### Trade-Off 2: Asynchronous Thumbnail Generation Versus Immediate Availability

Using a queue and background worker allows the application to accept uploads quickly without waiting for thumbnail generation. However, the thumbnail may not be available immediately after upload.

SnapShare can display a processing indicator or temporarily use the original photo until the thumbnail is ready.

### Trade-Off 3: Read Replicas Versus Read Consistency

A database read replica reduces read pressure on the primary database. However, replication can introduce a delay before newly written data becomes visible on the replica.

SnapShare can tolerate slightly delayed feed updates for ordinary browsing while reading critical, newly written data from the primary database when necessary.

### Trade-Off 4: Photo Quality Versus Storage and Delivery Cost

Keeping original photos preserves image quality but increases storage requirements and bandwidth consumption. Generating smaller thumbnails reduces the amount of data required for feed browsing, but thumbnail generation adds processing work and storage overhead.

SnapShare can retain originals for full-size viewing and use thumbnails for feed previews.

## 9. Conclusion

SnapShare has approximately 1,000,000 daily active users, 11.57 photo uploads per second, and 578.70 feed page views per second on average. It generates approximately 748.25 TB of new photo and thumbnail data per year under the stated assumptions.

Because feed views occur approximately 50 times as often as photo uploads, SnapShare is read-heavy. A CDN, load balancer, multiple application servers, cache, primary database, read replica, object storage, upload queue, and background thumbnail worker provide a foundation for scaling the application.

The system should also be monitored for peak traffic, database load, cache hit rate, queue backlog, image-processing failures, storage growth, and response times so that capacity can be increased as the application grows.
