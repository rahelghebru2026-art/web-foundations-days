# TicketHub: Concert and Event Ticketing System Design

## 1. Requirements

TicketHub is an online platform where customers discover concerts and events, view seat availability, reserve seats, pay for tickets, and access their purchased tickets.

The platform has 2 million registered users. It must support normal daily traffic and sudden demand when a popular concert goes on sale.

### 1.1 Functional Requirements

The system must allow customers to:

1. Register, log in, and manage their accounts.
2. Browse, search, and filter events by date, location, and category.
3. View event details, venues, ticket prices, and seat availability.
4. Select available seats and temporarily reserve them during checkout.
5. Pay for reserved tickets through a payment provider.
6. Receive order confirmation after successful payment.
7. View their purchased tickets and order history.
8. Cancel eligible orders and request refunds according to the event's cancellation policy.

Administrators must be able to create events, configure seats and prices, manage event information, and monitor sales.

### 1.2 Non-Functional Requirements

**Performance**

* Event pages should load within two seconds under normal operating conditions.
* Seat availability should update promptly after a reservation or purchase.
* The system should remain responsive during high-demand ticket releases.

**Correctness and consistency**

* A seat must never be sold to two customers for the same event.
* An order must not be confirmed until its payment has been verified.
* Seat assignments and order records must remain consistent.
* Retried requests must not create duplicate orders or charges.

**Fairness**

* Ticket allocation must follow a clear policy, such as first-come, first-served among eligible requests.
* A virtual waiting room should regulate access during high-demand sales.
* Rate limits and bot detection should reduce automated abuse.
* Repeated requests must not allow one customer to bypass the published queue policy.

**Availability and reliability**

* Multiple application servers should allow the system to continue operating if one server fails.
* Database backups and tested recovery procedures should reduce the risk of data loss.
* Temporary failures should be handled through safe retries and recovery mechanisms.

**Security**

* Users must authenticate before purchasing tickets or viewing private orders.
* Customers must only access their own orders and tickets.
* HTTPS must protect data in transit.
* A trusted payment provider should handle sensitive card information.

## 2. Traffic and Capacity Estimates

### 2.1 Given Information and Assumptions

The assignment provides these figures:

* Registered users: 2,000,000
* Normal daily visitors: 50,000
* Average pages viewed per visitor: 10
* Normal daily ticket sales: 5,000
* People attempting to buy tickets during a popular sale: 200,000
* Seats available for that popular concert: 20,000
* Duration of the initial sale period: 10 minutes

For the estimates below, assume that normal page views are distributed evenly over 24 hours and that each page view generates an average of three backend API requests. Real traffic will fluctuate, and a popular sale may produce much higher instantaneous peaks.

### 2.2 Normal Traffic

**Daily page views**

50,000 visitors × 10 pages per visitor = 500,000 page views per day.

**Average page requests per second**

500,000 ÷ 86,400 seconds per day = approximately 5.8 page views per second.

**Estimated backend API requests**

Assuming three backend API requests per page view:

500,000 × 3 = 1,500,000 API requests per day.

1,500,000 ÷ 86,400 = approximately 17.4 API requests per second.

**Normal ticket sales**

5,000 tickets ÷ 86,400 seconds = approximately 0.058 tickets sold per second on average.

This is an average across a full day, not the expected rate during a busy sales period.

### 2.3 Popular Concert Sale

During the popular concert sale, 200,000 people attempt to buy tickets within 10 minutes.

Ten minutes = 600 seconds.

**Average purchase attempts per second**

200,000 ÷ 600 = approximately 333 purchase attempts per second.

**Competition for seats**

200,000 interested customers ÷ 20,000 available seats = 10 customers per seat.

There are ten times as many interested customers as available seats.

The system must therefore reject or inform many customers that tickets are unavailable while ensuring that it never confirms more than 20,000 seat assignments for the event.

The 333 attempts per second figure is an average over the ten-minute window. Actual traffic may be considerably higher at the moment sales open.

### 2.4 Comparison

| Measurement                       |                               Normal day |                                             Popular concert sale |
| --------------------------------- | ---------------------------------------: | ---------------------------------------------------------------: |
| Visitors or purchase seekers      |                    50,000 daily visitors |                                     200,000 people in 10 minutes |
| Page views                        |                          500,000 per day |                                     Depends on browsing behavior |
| Estimated page views per second   |                              5.8 average |                                                May spike sharply |
| Estimated API requests per second |                             17.4 average |             At least 333 purchase attempts per second on average |
| Ticket demand                     |                 5,000 tickets sold daily |                        200,000 people competing for 20,000 seats |
| Main engineering concern          | Efficient browsing and routine purchases | Traffic spikes, concurrency, fairness, and inventory correctness |

Purchase attempts during the popular sale average about 19 times the estimated normal backend API request rate.

These figures represent different types of requests, so the comparison is approximate rather than a direct measurement of identical workloads.

### 2.5 Capacity Strategy

TicketHub should:

* Use a virtual waiting room to regulate the number of customers entering checkout.
* Scale application servers horizontally.
* Cache public event information and static resources.
* Keep authoritative seat-reservation decisions in the primary database.
* Use a queue for asynchronous tasks such as emails and analytics.
* Monitor response times, database connections, queue depth, and payment errors.
* Apply rate limits and backpressure when incoming traffic exceeds safe processing capacity.

The system should prioritize correct ticket allocation rather than accepting an unlimited number of checkout requests.

## 3. API Design

TicketHub uses HTTPS and JSON. Customers must authenticate before accessing private account, reservation, and purchase operations.

### 3.1 Browse Events

**Request**

`GET /api/events?page=1&date=2027-05-20`

**Purpose**

Returns published events with pagination and optional filters.

**Example response**

```json
{
  "events": [
    {
      "id": 101,
      "name": "Summer Music Festival",
      "venue": "City Arena",
      "startsAt": "2027-05-20T18:00:00Z"
    }
  ],
  "page": 1,
  "totalPages": 5
}
```

### 3.2 View Event Seats

**Request**

`GET /api/events/101/seats`

**Purpose**

Returns the seat map and the latest known seat status for an event.

**Example response**

```json
{
  "eventId": 101,
  "seats": [
    {
      "id": 501,
      "seatNumber": "A-01",
      "price": 50.00,
      "status": "available"
    },
    {
      "id": 502,
      "seatNumber": "A-02",
      "price": 50.00,
      "status": "held"
    }
  ]
}
```

Cached seat information is for display purposes only. The reservation endpoint must verify availability against the authoritative database.

### 3.3 Hold Seats

**Request**

`POST /api/events/101/holds`

**Example request body**

```json
{
  "seatIds": [501, 502],
  "idempotencyKey": "hold-request-abc123"
}
```

**Purpose**

Attempts to hold the requested seats temporarily for the authenticated customer.

A successful hold expires after a defined period, such as five minutes.

**Example response**

```json
{
  "holdId": "hold-9001",
  "eventId": 101,
  "seatIds": [501, 502],
  "status": "held",
  "expiresAt": "2027-05-20T12:05:00Z"
}
```

If another customer has already reserved a requested seat, the server returns `409 Conflict`.

### 3.4 Purchase Tickets

**Request**

`POST /api/orders`

**Example request body**

```json
{
  "holdId": "hold-9001",
  "paymentMethodToken": "provider-token-xyz",
  "idempotencyKey": "order-request-abc123"
}
```

**Purpose**

Validates the hold and coordinates payment through the payment provider.

The order is confirmed only after successful payment has been verified and the seat assignment has been committed correctly.

**Example response**

```json
{
  "orderId": 7001,
  "status": "confirmed",
  "totalAmount": 100.00,
  "currency": "USD"
}
```

If payment is still processing, the server should return a pending status instead of claiming that the order is confirmed.

### 3.5 View My Tickets

**Request**

`GET /api/me/tickets`

**Purpose**

Returns the authenticated customer's purchased tickets.

**Example response**

```json
{
  "tickets": [
    {
      "ticketId": 8001,
      "eventId": 101,
      "eventName": "Summer Music Festival",
      "seatNumber": "A-01",
      "status": "confirmed"
    }
  ]
}
```

The server must verify the customer's identity and ticket ownership.

### 3.6 View Order Details

**Request**

`GET /api/orders/7001`

**Purpose**

Returns an order's details, purchased seats, payment status, and total amount.

Only the order owner or an authorized administrator may access the order.

### 3.7 Cancel an Order

**Request**

`POST /api/orders/7001/cancel`

**Purpose**

Requests cancellation of an eligible order and coordinates any required refund.

The system must verify the cancellation policy and payment status. It must not release a sold seat until the cancellation process has safely established that the seat can be returned to inventory.

### 3.8 Error Responses

| HTTP status               | Meaning                                                                 |
| ------------------------- | ----------------------------------------------------------------------- |
| 400 Bad Request           | Invalid request or missing required information                         |
| 401 Unauthorized          | Authentication is missing or invalid                                    |
| 403 Forbidden             | The user is not permitted to perform the operation                      |
| 404 Not Found             | The requested resource does not exist                                   |
| 409 Conflict              | The seat is unavailable, the hold expired, or a state conflict occurred |
| 422 Unprocessable Content | A business rule prevents processing                                     |
| 429 Too Many Requests     | The rate limit has been exceeded                                        |
| 500 Internal Server Error | An unexpected server error occurred                                     |
| 503 Service Unavailable   | The service is temporarily unavailable                                  |

Hold and purchase endpoints should support idempotency keys. Repeating the same logical request must not create duplicate orders or charges.

## 4. Data Model

TicketHub uses PostgreSQL because ticket purchases require reliable transactions, constraints, and relationships.

### 4.1 Main Tables

The design includes six tables:

1. **users** — stores customer account information.
2. **events** — stores event details and dates.
3. **seats** — stores the seats belonging to each event.
4. **orders** — stores purchase and payment status.
5. **order_items** — links orders to the individual seats purchased.
6. **seat_holds** — records temporary reservations and their expiration times.

### 4.2 Relationships

* One user can create many orders.
* One event has many seats.
* One user can hold seats temporarily.
* One order can contain multiple order items.
* Each order item references one seat.
* A seat can belong to at most one successful order.
* A seat hold records which user temporarily reserved a seat.

### 4.3 SQL Schema

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    venue VARCHAR(200) NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (status IN ('draft', 'published', 'cancelled'))
);

CREATE TABLE seats (
    id BIGSERIAL PRIMARY KEY,
    event_id BIGINT NOT NULL REFERENCES events(id),
    seat_number VARCHAR(30) NOT NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'available',
    UNIQUE (event_id, seat_number),
    CHECK (status IN ('available', 'held', 'sold'))
);

CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    idempotency_key VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (status IN ('pending', 'confirmed', 'failed', 'cancelled'))
);

CREATE TABLE order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id),
    seat_id BIGINT NOT NULL REFERENCES seats(id),
    ticket_price NUMERIC(10, 2) NOT NULL CHECK (ticket_price >= 0),
    UNIQUE (seat_id)
);

CREATE TABLE seat_holds (
    id BIGSERIAL PRIMARY KEY,
    seat_id BIGINT NOT NULL REFERENCES seats(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (status IN ('active', 'converted', 'expired', 'cancelled'))
);
```

### 4.4 Preventing Double-Booking

Double-booking happens when two customers try to purchase the same seat at nearly the same time.

TicketHub prevents this using database transactions, row-level locks, temporary holds, and unique constraints.

**Step 1: Begin a transaction.**

The application begins a transaction when a customer attempts to reserve a seat.

**Step 2: Lock the seat row.**

The application selects the requested seat using `SELECT ... FOR UPDATE`. This prevents two transactions from simultaneously modifying the same seat row.

**Step 3: Check availability.**

After acquiring the lock, the application verifies that the seat is available or that an earlier hold has expired.

**Step 4: Create a temporary hold.**

If the seat is available, the application records the hold and marks the seat as held in the same transaction.

**Step 5: Commit the hold.**

The application commits the transaction. A competing customer must wait for the lock and then sees the updated seat status.

**Step 6: Complete payment and confirm the order.**

After payment is successfully verified, the application confirms the order, changes the seat to sold, and creates the order item in a database transaction.

**Step 7: Release expired holds.**

A background worker identifies expired holds and releases seats that have not been sold or converted into valid orders.

The `UNIQUE (seat_id)` constraint in `order_items` provides an additional safeguard against assigning the same seat to two orders.

**Important:** A database transaction cannot atomically include an external payment provider. TicketHub must handle delayed payment responses, retries, duplicate notifications, and payment timeouts using idempotency keys and a clearly defined payment state machine.

The application must not confirm a seat for two customers while waiting for payment. The seat remains protected until the hold is safely converted, released, or expired.

## 5. Architecture

### 5.1 Architecture Diagram

```text
                          Customers
                              |
                              v
                         DNS / HTTPS
                              |
                              v
                      CDN / Web Frontend
                              |
                              v
                    Load Balancer / WAF
                              |
                              v
                    Virtual Waiting Room
                              |
                              v
                 +------------+------------+
                 |                         |
                 v                         v
         Application Server A     Application Server B
                 |                         |
                 +------------+------------+
                              |
               +--------------+--------------+
               |              |              |
               v              v              v
             Cache      PostgreSQL       Message Queue
                         Primary DB           |
                              |                v
                              v         Background Workers
                         Read Replica          |
                                               v
                                        Payment Provider
```

### 5.2 Explanation of Each Component

**Customers**

Customers use TicketHub to browse events, choose seats, purchase tickets, and view their orders.

**DNS and HTTPS**

DNS directs users to TicketHub. HTTPS encrypts communication and protects data in transit.

**CDN and Web Frontend**

The CDN serves static resources, such as event posters, images, CSS, and JavaScript. This reduces repeated requests to application servers and improves page-loading speed.

**Load Balancer and WAF**

The load balancer distributes requests across healthy application servers. The web application firewall filters suspicious traffic. Health checks help prevent routing requests to failed instances.

**Virtual Waiting Room**

The waiting room controls how quickly customers enter a high-demand sale. It reduces sudden pressure on the checkout service and helps apply a clear, fair queue policy.

**Application Servers**

Application servers implement authentication, event browsing, seat reservation, checkout, order management, and ticket retrieval. Multiple instances support horizontal scaling and reduce dependence on one server.

**Cache**

The cache stores frequently accessed public information, such as event details and venue information. It reduces database load. It is not the authoritative source for seat ownership.

**PostgreSQL Primary Database**

The primary database stores users, events, seats, holds, and orders. Transactions, row locks, and unique constraints protect seat inventory and order consistency.

**Read Replica**

The read replica serves suitable read-heavy queries and reduces the primary database's read workload. Because replication can lag, critical reservation and checkout decisions must use the primary database.

**Message Queue**

The message queue stores asynchronous tasks, such as confirmation emails and analytics updates. It allows these tasks to run without unnecessarily delaying the main purchase request.

**Background Workers**

Background workers process queued jobs, retry transient failures, release expired holds, and handle other scheduled work. Workers should be idempotent so that retries do not create duplicate effects.

**Payment Provider**

The payment provider processes customer payments. TicketHub stores payment references and statuses instead of raw payment-card details. Payment notifications must be verified and handled safely.

### 5.3 Handling a Popular Sale

When 200,000 people compete for 20,000 seats, the waiting room regulates incoming purchase requests. The CDN and cache serve public information, while application servers scale horizontally to process allowed traffic.

The primary database remains responsible for seat reservations and purchase confirmation. Transactions and unique constraints prevent conflicting seat assignments.

A message queue handles non-critical tasks outside the main checkout path. Monitoring detects database overload, increasing response times, queue growth, and payment errors.

The system should use backpressure and controlled admission when demand exceeds safe capacity rather than accepting more confirmed purchases than available seats.

## 6. Trade-Offs

### 6.1 Consistency vs. Availability During Checkout

TicketHub must balance availability with consistency.

**Consistency** means that critical checkout operations use authoritative inventory information and preserve correct seat ownership.

**Availability** means that customers can continue using the service and receiving responses.

During a popular sale, two customers may try to purchase the same seat simultaneously. If the system trusts stale cached data or a delayed read replica, both customers might see the seat as available.

To prevent double-booking, TicketHub verifies availability and reserves seats through transactions against the primary PostgreSQL database. Row-level locks coordinate competing operations, while a unique constraint on `order_items.seat_id` provides an additional safeguard.

If the primary database becomes unavailable, the system should temporarily pause or defer new reservations and purchases rather than confirm a seat without verifying its ownership. Public event information can remain available through the CDN and cache.

**Advantages:**

* Prevents two customers from purchasing the same seat.
* Keeps seat assignments and confirmed orders consistent.
* Avoids promising tickets that are no longer available.

**Disadvantages:**

* Checkout may become temporarily unavailable during a database failure.
* Database locks and transaction checks can increase latency during heavy traffic.
* Customers may need to retry when reservations cannot be confirmed.

**Decision:** TicketHub prioritizes consistency for checkout because double-booking damages customer trust and creates financial and operational problems. It improves availability through redundant application servers, database failover, caching, and a waiting room without treating stale cached information as proof that a seat is available.

### 6.2 SQL Database vs. NoSQL Database

TicketHub uses PostgreSQL for inventory and orders.

**Advantages:**

* ACID transactions support reliable seat reservations.
* Unique constraints prevent duplicate seat assignments.
* Foreign keys preserve relationships between users, events, seats, and orders.

**Disadvantages:**

* A heavily loaded primary database can become a bottleneck.
* Transactions and row locks require careful design.
* Scaling writes across database nodes can add complexity.

PostgreSQL is appropriate because correctness and transaction support are critical for ticket sales.

### 6.3 Virtual Waiting Room vs. Immediate Access

TicketHub uses a virtual waiting room during high-demand sales.

**Advantages:**

* Reduces sudden pressure on application servers and the database.
* Provides a predictable way to regulate incoming requests.
* Supports a clearly communicated ticket-allocation policy.

**Disadvantages:**

* Customers may have to wait before purchasing.
* Queue infrastructure adds operational complexity.
* Poor queue design can create unfairness or become a bottleneck.

The waiting room should follow a documented fairness policy and regulate demand according to the capacity of the reservation service.

### 6.4 Cache Performance vs. Freshness

TicketHub caches public event information to improve performance.

**Advantages:**

* Reduces database reads.
* Improves response times.
* Helps the platform handle high browsing traffic.

**Disadvantages:**

* Cached information can become outdated.
* Cache invalidation adds complexity.
* Incorrectly trusting cached seat availability can lead to failed purchases.

The system can tolerate brief delays in refreshing public event descriptions, but checkout must always validate inventory against the authoritative database.

## 7. Redundancy and Failure Recovery

TicketHub should avoid single points of failure.

**Application servers:** Run multiple instances. If one instance fails, the load balancer redirects traffic to healthy instances.

**Load balancing:** Use a managed or redundant load-balancing service so that a single load-balancer failure does not make the application unreachable.

**Database:** Maintain a standby replica and tested backup and restoration procedures. If the primary database fails, an appropriately configured failover process can promote a healthy standby. New checkout operations should remain paused until the system can safely verify inventory.

**Cache:** Treat the cache as an optimization rather than the source of truth. If it fails, the application may temporarily read from the database, subject to capacity limits.

**Message queue:** Use a durable, appropriately redundant queue. Workers should safely retry jobs without producing duplicate effects.

**Monitoring:** Monitor server health, database latency, connection usage, queue depth, and payment errors. Test failover and recovery procedures regularly.

Redundancy reduces the risk of downtime but increases cost and operational complexity. Recovery depends on correct configuration, monitoring, backups, and testing.

## 8. Conclusion

TicketHub must support normal event browsing and sudden demand for limited ticket inventory.

The design separates scalable browsing traffic from correctness-critical reservation and checkout operations. A CDN, cache, load balancer, waiting room, and multiple application servers help manage high traffic.

PostgreSQL transactions, row-level locks, temporary holds, and unique constraints protect seat inventory from double-booking. Idempotency keys and payment-state handling help prevent duplicate orders and charges.

The most important design decision is to prioritize correct ticket ownership during checkout, even if a temporary database failure requires the system to defer purchases. This protects customers, prevents overselling, and preserves trust in the platform.
