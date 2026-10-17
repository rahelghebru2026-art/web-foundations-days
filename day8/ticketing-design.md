# TicketHub System Design Document

## 1. Requirements

### Functional Requirements
- **Event Discovery:** Users can search and browse listed events (concerts, shows) and view available seating maps.
- **Ticket Reservation & Purchase:** Users can select specific seats, temporarily hold/reserve them, and complete checkout via a payment provider.
- **Prevent Double-Booking:** The system strictly prevents two users from purchasing the same seat for an event under all conditions.
- **Ticket Management:** Users can view purchased tickets, display digital pass QR codes, or cancel reservations before purchase completion.

### Non-Functional Requirements
- **High Availability & Fault Tolerance:** 99.99% uptime SLA to handle massive flash-sale spikes without server crashes.
- **Low Latency:** Seat availability updates and search responses must take < 100ms globally.
- **Consistency over Availability during Flash Sales:** Strict ACID compliance for ticket transactions to eliminate overbooking.

---

## 2. Load Estimates & Traffic Profiles

### Normal Day Metrics
- **Registered Users:** 2,000,000 users.
- **Daily Active Users (DAU):** 50,000 visitors.
- **Page Views (Reads):** 50,000 visitors × 10 pages = 500,000 reads/day.
  - *Average Read QPS:* $500,000 / 86,400 \text{ sec} \approx \mathbf{5.79 \text{ reads/sec}}$.
- **Ticket Sales (Writes):** 5,000 tickets sold/day.
  - *Average Write QPS:* $5,000 / 86,400 \text{ sec} \approx \mathbf{0.058 \text{ writes/sec}}$.

### Flash Sale Metrics (Popular Concert Event)
- **Traffic Burst:** 200,000 simultaneous users competing for 20,000 available seats within a 10-minute (600 seconds) window.
- **Peak Flash-Sale Reads (Browsing seats/status):** Assuming each user refreshes or queries seat maps 20 times during the 10 minutes ($4,000,000$ total reads):
  - *Peak Read QPS:* $4,000,000 / 600 \text{ sec} \approx \mathbf{6,666.67 \text{ reads/sec}}$.
- **Peak Flash-Sale Writes (Reservation requests):** 200,000 purchase attempts over 600 seconds:
  - *Peak Write QPS:* $200,000 / 600 \text{ sec} \approx \mathbf{333.33 \text{ writes/sec}}$.

---

## 3. REST API Endpoints

1. **`GET /api/v1/events`**
   - **Description:** List upcoming events with search and pagination support.
   - **Success Code:** `200 OK`
2. **`GET /api/v1/events/{id}/seats`**
   - **Description:** Fetch seat layout and real-time availability status for a specific event.
   - **Success Code:** `200 OK`
3. **`POST /api/v1/reservations`**
   - **Description:** Attempt a temporary lock/hold on selected seat(s) for 10 minutes.
   - **Success Code:** `201 Created`
4. **`POST /api/v1/payments/checkout`**
   - **Description:** Process payment for a reserved seat lock and confirm booking.
   - **Success Code:** `200 OK`
5. **`GET /api/v1/users/{id}/tickets`**
   - **Description:** Retrieve a user's active digital tickets and QR codes.
   - **Success Code:** `200 OK`

---

## 4. Data Model

### Tables & Schema Structure

1. **`users`**
   - `user_id` (INT, PK, Auto-Increment)
   - `email` (VARCHAR, Unique, NOT NULL)
   - `name` (VARCHAR, NOT NULL)

2. **`events`**
   - `event_id` (INT, PK, Auto-Increment)
   - `title` (VARCHAR, NOT NULL)
   - `venue` (VARCHAR, NOT NULL)
   - `event_date` (DATETIME, NOT NULL)

3. **`seats`**
   - `seat_id` (INT, PK, Auto-Increment)
   - `event_id` (INT, FK -> `events.event_id`, NOT NULL)
   - `seat_number` (VARCHAR, NOT NULL)
   - `price` (DECIMAL, NOT NULL)
   - `status` (ENUM: `'AVAILABLE'`, `'RESERVED'`, `'SOLD'`, DEFAULT `'AVAILABLE'`)
   - `version` (INT, DEFAULT 0) — *Used for Optimistic Locking*

4. **`bookings`**
   - `booking_id` (INT, PK, Auto-Increment)
   - `user_id` (INT, FK -> `users.user_id`, NOT NULL)
   - `seat_id` (INT, FK -> `seats.seat_id`, NOT NULL)
   - `reserved_until` (DATETIME, NOT NULL)
   - `payment_status` (ENUM: `'PENDING'`, `'COMPLETED'`, `'EXPIRED'`)

### Relationships
- **One-to-Many (`events` to `seats`):** An event has thousands of individual seats, but each seat belong to one event.
- **One-to-Many (`users` to `bookings`):** A user can create multiple bookings over time.
- **One-to-One (`seats` to `bookings` during lock):** Each seat connects to at most one active booking record at any given time.

---

## 5. Preventing Double-Booking (Concurrency Control)

To prevent two people from buying the same seat during high-demand flash sales, TicketHub employs a **Two-Tier Locking Strategy**:

1. **In-Memory Distributed Lock (Redis Atomic Operations):**
   When a user clicks "Reserve Seat", the API attempts an atomic `SETNX` (Set if Not Exists) operation in Redis:
   `SET seat_lock:event_123:seat_45 user_789 EX 600 NX`
   If the lock key already exists, the request fails instantly with a `409 Conflict` status code, preventing database bloat from excess traffic.

2. **Database Optimistic Locking with Versioning:**
   When persisting the hold to PostgreSQL, the update query evaluates both seat status and version:
   ```sql
   UPDATE seats 
   SET status = 'RESERVED', version = version + 1 
   WHERE seat_id = 45 AND status = 'AVAILABLE' AND version = 12;
   [ Mobile / Web Clients ]
           │
           ▼
        [ CDN ] (Static Content & Seat Map Caching)
           │
           ▼
  [ Load Balancer ] (Nginx / Cloud Rate Limiter)
           │
           ▼
  [ API Gateway / App Servers ]
           │
  ┌────────┼─────────────────┬──────────────────┐
  ▼        ▼                 ▼                  ▼
[ Virtual Queue ]  [ Redis Lock Engine ]  [ Primary DB ]  [ Message Queue ]
(Kafka Queue)      (Atomic Seat Locks)    (PostgreSQL)    (Payment Workers)
                                                │                 │
                                                ▼                 ▼
                                         [ Read Replica ]  [ Payment Gateway ]


### File 2: `day8/reflection.md`

```markdown
# Course Reflection

### What was the most difficult concept in the course, and how did you overcome it?
The most challenging concept in this course was understanding system architecture trade-offs under heavy load—specifically balancing database consistency against high availability (the CAP theorem) during flash sales. Visualizing how distributed systems maintain state across caching layers (Redis) and relational databases without race conditions required a shift in mindset from simple single-user web applications to large-scale distributed computing. I overcame this by breaking down system execution into step-by-step request flows, sketching architecture diagrams, and calculating concrete metrics like peak read/write queries per second (QPS) to make abstract trade-offs tangible.

### Which part of your capstone would you improve, based on the feedback you received?
Based on feedback received on my QuickNotes system design capstone, I would improve the cache invalidation and database synchronization strategies. While my initial design utilized a Redis cache for fast reads, I relied on simple cache invalidations on updates. Implementing a more robust write-through caching pattern or utilizing asynchronous change data capture (CDC) via event streams would significantly reduce database strain and eliminate potential race conditions during high-concurrency write operations.

### What will you learn next?
Next, I plan to deepen my knowledge of backend infrastructure and cloud orchestration. Specifically, I intend to learn Docker containerization, Kubernetes for automated service scaling, and advanced distributed messaging systems like Apache Kafka. Mastering these tools will allow me to turn these architectural design documents into production-ready microservices capable of serving millions of concurrent users reliably.