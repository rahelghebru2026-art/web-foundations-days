# TicketHub: Ticketing System Design

## 1. Requirements

TicketHub is an online platform where users can discover concerts and events, view available seats, reserve seats temporarily, purchase tickets, and access their purchased tickets.

The platform has 2 million registered users and must handle both normal traffic and sudden demand when popular concert tickets go on sale.

### 1.1 Functional Requirements

The system must allow users to:

1. Register, log in, and manage their accounts.
2. Browse and search concerts and events.
3. View event details, prices, venue information, and available seats.
4. Select available seats and temporarily hold them while completing checkout.
5. Pay for reserved tickets through a payment provider.
6. Receive confirmation after successful payment.
7. View their purchased tickets and order history.
8. Cancel eligible orders and receive refunds according to the event's cancellation policy.

The system must also allow administrators to create events, configure seats and prices, and monitor ticket sales.

### 1.2 Non-Functional Requirements

**Performance**

* Event listings and event details should load within two seconds under normal operating conditions.
* Seat availability should update quickly after a reservation or purchase.
* The system should remain responsive when a popular event attracts hundreds of thousands of visitors.

**Correctness and consistency**

* A seat must never be sold to two different customers for the same event.
* A customer must not receive a confirmed ticket until payment has been successfully verified.
* Order records, payment records, and seat assignments must remain consistent.
* Repeated payment notifications must not create duplicate orders or charges.

**Fairness**

* Ticket allocation should follow a clearly communicated policy, such as first-come, first-served among eligible requests.
* The system should apply rate limits and bot detection to reduce automated abuse.
* Users should receive clear information about their place in a virtual waiting room when one is used.
* A user must not obtain an unfair advantage simply by sending the same purchase request repeatedly.

**Availability and reliability**

* The service should continue operating if an application server fails.
* Failed payment attempts must not result in confirmed tickets.
* Temporary failures should be handled through safe retries and recovery procedures.

**Security**

* Authentication is required for purchases and access to personal tickets.
* Users must only access their own orders and tickets.
* Payment card details should be handled by a trusted payment provider rather than stored directly by TicketHub.
* All communication should use HTTPS.

## 2. Traffic and Capacity Estimates

### 2.1 Given Information

* Registered users: 2,000,000
* Normal daily visitors: 50,000
* Average pages viewed per visitor: 10
* Normal daily ticket sales: 5,000
* Popular concert seats: 20,000
* People attempting to buy tickets during the first 10 minutes: 200,000

These calculations are estimates, not measured production traffic.

### 2.2 Normal Daily Traffic

Daily page views:

50,000 visitors × 10 pages = 500,000 page views per day.

Assuming page views are distributed evenly across 24 hours:

Average page requests per second:

500,000 ÷ 86,400 = approximately 5.8 requests per second.

This estimate covers page views, not every API request. A page may generate additional requests for event data, seat availability, images, and other resources.

Assuming each page view generates an average of three backend API requests:

500,000 × 3 = 1,500,000 API requests per day.

Average API request rate:

1,500,000 ÷ 86,400 = approximately 17.4 requests per second.

Normal daily ticket sales are 5,000. If sales were distributed evenly across 24 hours, the average would be:

5,000 ÷ 86,400 = approximately 0.058 tickets per second.

Actual sales are not evenly distributed, so real purchase traffic will be higher during busy periods.

### 2.3 Popular Concert Sale

During a popular concert sale, 200,000 people attempt to buy tickets within 10 minutes.

Ten minutes = 600 seconds.

Average incoming purchase attempts:

200,000 ÷ 600 = approximately 333 attempts per second.

The event has only 20,000 seats.

Number of interested buyers per available seat:

200,000 ÷ 20,000 = 10 people per seat.

Therefore, demand is ten times the available inventory.

If all 200,000 people submit requests at roughly the same rate, the system must handle approximately 333 purchase attempts per second on average during the sale. The instantaneous peak may be considerably higher if many people arrive at the same moment.

### 2.4 Comparison

| Measurement                             |                               Normal day |                            Popular concert sale |
| --------------------------------------- | ---------------------------------------: | ----------------------------------------------: |
| Visitors or purchase seekers            |                    50,000 daily visitors |                        200,000 purchase seekers |
| Page views                              |                          500,000 per day |  Additional browsing and seat-selection traffic |
| Estimated average page requests         |                           5.8 per second |                    Depends on browsing behavior |
| Estimated average API requests          | 17.4 per second, assuming three per page |  Purchase attempts alone average 333 per second |
| Available tickets for the relevant sale |                  Normal inventory varies |                                          20,000 |
| Ticket demand                           |                 5,000 tickets sold daily | Up to 200,000 people competing for 20,000 seats |

The popular sale creates a much more demanding workload. Purchase requests alone average approximately 19 times the estimated normal API request rate.

This comparison does not mean that the two request rates measure exactly the same workload: one represents estimated general API traffic, while the other represents purchase attempts during a specific sale.

### 2.5 Capacity Strategy

The system should be designed to handle sudden traffic spikes by:

* Placing a virtual waiting room in front of the purchase workflow.
* Using a queue to regulate how many customers enter the seat-reservation process at once.
* Caching public event information.
* Keeping seat availability and purchase confirmation under authoritative database control.
* Scaling application servers horizontally.
* Monitoring queue depth, database latency, payment failures, and reservation expiration rates.

The system must not accept more confirmed seat assignments than the event has available seats.

## 3. API Design

The API uses HTTPS and JSON. Authenticated endpoints require a valid access token.

### 3.1 Browse Events

**Request**

GET /api/events?date=2027-05-20&page=1

**Purpose**

Returns a paginated list of published events. Users can filter by date, location, or category.

**Example response**

```json
{
  "events": [
    {
      "id": 101,
      "name": "Summer Music Festival",
      "date": "2027-05-20T18:00:00Z",
      "venue": "City Arena"
    }
  ],
  "page": 1,
  "totalPages": 5
}
```

### 3.2 View Event Seats

**Request**

GET /api/events/101/seats

**Purpose**

Returns the seat map and the latest available seat information for event 101.

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

The seat map may be cached briefly for display purposes, but the reservation endpoint must always verify availability against the authoritative database.

### 3.3 Hold Seats

**Request**

POST /api/events/101/holds

**Example request body**

```json
{
  "seatIds": [501, 502],
  "idempotencyKey": "hold-request-abc123"
}
```

**Purpose**

Attempts to reserve the requested seats temporarily for the authenticated user.

If the requested seats are available, the system creates a hold with an expiration time, such as five minutes from creation.

**Example success response**

```json
{
  "holdId": "hold-9001",
  "eventId": 101,
  "seatIds": [501, 502],
  "status": "held",
  "expiresAt": "2027-05-20T12:05:00Z"
}
```

If any requested seat is no longer available, the system returns a conflict response rather than promising an unavailable seat.

### 3.4 Purchase Tickets

**Request**

POST /api/orders

**Example request body**

```json
{
  "holdId": "hold-9001",
  "paymentMethodToken": "provider-token-xyz",
  "idempotencyKey": "order-request-abc123"
}
```

**Purpose**

Validates the hold, initiates payment through the payment provider, and creates an order after payment is confirmed.

**Example success response**

```json
{
  "orderId": 7001,
  "status": "confirmed",
  "totalAmount": 100.00,
  "currency": "USD"
}
```

If payment is still processing, the API should return a pending status instead of claiming that the order is confirmed.

### 3.5 View My Tickets

**Request**

GET /api/me/tickets

**Purpose**

Returns tickets belonging to the authenticated user.

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

The server must verify the user's identity and ownership before returning tickets.

### 3.6 View Order Details

**Request**

GET /api/orders/7001

**Purpose**

Returns order details, including the seats purchased, payment status, and total amount.

Only the order owner or an authorized administrator may access the order.

### 3.7 Important Error Responses

| HTTP status               | Meaning                                                                      |
| ------------------------- | ---------------------------------------------------------------------------- |
| 400 Bad Request           | Invalid request body or missing required information                         |
| 401 Unauthorized          | Authentication is missing or invalid                                         |
| 403 Forbidden             | The user is not allowed to perform the operation                             |
| 404 Not Found             | The requested event, seat, hold, or order does not exist                     |
| 409 Conflict              | A seat is already held or sold, or a hold has expired                        |
| 422 Unprocessable Content | The request is understood but cannot be processed because of a business rule |
| 429 Too Many Requests     | The client has exceeded its rate limit                                       |
| 500 Internal Server Error | An unexpected server failure occurred                                        |
| 503 Service Unavailable   | The system is temporarily unable to accept requests                          |

Purchase and hold endpoints should support idempotency keys. Repeating the same logical request with the same key must not create duplicate orders or charges.

## 4. Data Model

TicketHub uses PostgreSQL because ticket purchases require reliable transactions, constraints, and relationships between users, events, seats, and orders.

The core tables are users, events, seats, and orders. A separate order_items table records which seats belong to each order.

### 4.1 Relationships

* One user can create many orders.
* One event has many seats.
* One event can have many orders.
* One order contains one or more order items.
* Each order item refers to a specific seat.
* A seat can be assigned to at most one successful order for its event.

Temporary seat holds should also be represented explicitly, for example in a seat_holds table. A hold records the user, seat, expiration time, and hold status.

### 4.2 Example SQL Schema

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

The `UNIQUE (event_id, seat_number)` constraint prevents the same seat label from being registered twice for one event.

The `UNIQUE (seat_id)` constraint in order_items prevents a seat from appearing in two different orders. It is a final database safeguard against double-booking.

The `UNIQUE (idempotency_key)` constraint prevents the same order request key from creating multiple orders. In a production system, the key should be scoped appropriately to the user or operation, and the system should return the original result for a repeated request.

The schema above is a starting point. A production implementation should also enforce that an order item can only be created from a valid hold for the same event and that the seat is changed to sold atomically with the confirmed order.

### 4.3 How Double-Booking Is Prevented

Double-booking occurs when two customers attempt to purchase the same seat at nearly the same time.

TicketHub prevents this through a combination of database transactions, row locking, temporary holds, and unique constraints.

**Step 1: Begin a database transaction.**

When a customer requests a seat, the application begins a transaction.

**Step 2: Lock the requested seat row.**

The application locks the seat row using `SELECT ... FOR UPDATE`. If another transaction is already holding that row lock, the competing transaction must wait.

**Step 3: Verify availability.**

After acquiring the lock, the application checks whether the seat is available or whether an existing hold has expired.

**Step 4: Create the temporary hold.**

If the seat is available, the application records the hold and marks the seat as held within the same transaction. The hold receives an expiration time.

**Step 5: Commit the transaction.**

The application commits the hold. A competing customer can no longer obtain the same seat while the first hold remains valid.

**Step 6: Complete payment and confirm the order.**

The application verifies the hold and processes payment through the payment provider. After successful payment is confirmed, it changes the seat to sold and creates the order item in a database transaction.

**Step 7: Release expired holds.**

A background worker periodically finds expired holds and releases their seats, provided they have not already been sold or converted into a valid order.

If two customers request the same seat simultaneously, only one can successfully acquire and reserve it. The other receives a conflict response such as HTTP 409.

The unique constraint on `order_items.seat_id` provides an additional database-level safeguard.

**Important payment consideration:** A database transaction cannot atomically include an external payment provider. The application must handle pending payments, timeouts, duplicate payment notifications, and retries using idempotency keys and a clear payment state machine. It must never confirm the same seat for two customers while waiting for payment.

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
             +-----------+-----------+
             |                       |
             v                       v
       Application Server A   Application Server B
             |                       |
             +-----------+-----------+
                         |
             +-----------+-----------+
             |           |           |
             v           v           v
         Cache       PostgreSQL    Message Queue
                     Primary DB         |
                         |               v
                         v          Background Workers
                   Read Replica          |
                                         v
                                  Payment Provider
```

This diagram shows the major logical components. In a production deployment, the database, load balancer, and other critical services should use appropriate redundancy and recovery mechanisms.

### 5.2 Component Explanations

**DNS and HTTPS**

DNS directs users to the TicketHub service. HTTPS encrypts traffic between users and the platform.

**CDN and Web Frontend**

The content delivery network serves static files such as JavaScript, CSS, images, and event posters. Caching these files reduces the load on application servers.

**Load Balancer and Web Application Firewall**

The load balancer distributes requests across healthy application servers. The web application firewall helps filter malicious traffic.

**Virtual Waiting Room**

During a major ticket release, a waiting room regulates entry to the purchasing workflow. It limits how many purchase attempts reach the reservation system simultaneously and communicates queue status to users.

The waiting room must use a fair, documented allocation policy rather than allowing users to bypass the queue by repeatedly refreshing the page.

**Application Servers**

Application servers implement authentication, event browsing, seat reservations, order processing, and ticket retrieval. Multiple instances allow the service to scale horizontally.

**Cache**

The cache stores frequently accessed public information, such as event details and venue information. It improves performance and reduces database reads.

The cache is not the authoritative source for seat ownership. Seat reservations and sales must be validated against the database.

**PostgreSQL Primary Database**

The primary database stores users, events, seats, holds, and orders. Transactions, row locks, and unique constraints protect ticket inventory from conflicting purchases.

**Read Replica**

A read replica can serve suitable read-heavy queries, such as historical order reports or some event listings. It reduces the primary database's read workload.

Because replication can lag, the system must use the primary database for critical seat availability and purchase confirmation checks.

**Message Queue and Background Workers**

The queue buffers asynchronous tasks such as sending confirmation emails, generating ticket files, processing analytics, and handling retryable jobs.

Workers can process tasks independently of the main request path. Durable queues and idempotent workers help recover from failures.

**Payment Provider**

A payment provider processes customer payments. TicketHub stores payment references and statuses rather than raw card details. Payment callbacks must be authenticated and handled idempotently.

### 5.3 How the Architecture Handles a Big Sale

During a popular concert sale, approximately 200,000 people compete for 20,000 seats.

The virtual waiting room regulates the flow of customers into the purchase process. Application servers scale horizontally to handle the permitted workload.

The CDN and cache serve public information without requiring every request to reach the primary database.

The database remains responsible for authoritative seat reservations. Row locking and unique constraints prevent conflicting seat assignments, even if multiple application servers process requests simultaneously.

A message queue handles tasks that do not need to finish before the purchase response, such as confirmation emails and analytics.

Monitoring detects increasing response times, database connection exhaustion, queue growth, and payment errors. Rate limits and backpressure help protect the database when demand exceeds the system's safe processing capacity.

The platform should prioritize correct inventory and payment handling over accepting an unlimited number of purchase requests.

## 6. Trade-Offs

### Trade-Off 1: SQL Database vs. NoSQL Database

**Decision:** Use PostgreSQL for ticket inventory and orders.

**Advantages:**

* ACID transactions support reliable seat reservations.
* Unique constraints prevent duplicate seat assignments.
* Foreign keys preserve relationships between users, events, seats, and orders.
* Row-level locking coordinates competing purchases.

**Disadvantages:**

* A heavily loaded primary database can become a bottleneck.
* Transactions and locks require careful design to avoid excessive contention.
* Scaling writes across multiple database nodes is more complex than scaling stateless application servers.

For this use case, transaction correctness is more important than choosing a database solely for its ability to distribute large volumes of data.

### Trade-Off 2: Strong Consistency vs. Read Performance

**Decision:** Use the primary database for critical seat reservations and purchase confirmation, while using caching and read replicas for suitable browsing requests.

**Advantages:**

* Purchase decisions use authoritative inventory data.
* Caching improves performance for frequently requested public information.
* Read replicas reduce the workload on the primary database.

**Disadvantages:**

* Some read queries may return slightly outdated information.
* Routing critical requests to the primary database increases its workload.
* Cache invalidation and consistency require additional engineering.

This is an intentional choice: browsing can tolerate brief delays in freshness, but ticket ownership cannot tolerate conflicting assignments.

### Trade-Off 3: Immediate Purchase Access vs. Virtual Waiting Room

**Decision:** Introduce a waiting room during high-demand sales.

**Advantages:**

* Limits sudden pressure on application servers and the database.
* Makes access more predictable during a major sale.
* Provides a place to apply fair queueing and abuse prevention.

**Disadvantages:**

* Users may wait before purchasing.
* Queue infrastructure adds complexity.
* A poorly designed queue may create unfairness or become a bottleneck.

The waiting room should be enabled according to demand and operate with a clear, documented policy.

## 7. Conclusion

TicketHub must support ordinary event browsing and sudden, intense demand for limited ticket inventory.

The main design principle is to separate scalable browsing traffic from correctness-critical reservation and purchase operations.

A CDN, cache, load balancer, multiple application servers, waiting room, and message queue help manage high traffic. PostgreSQL transactions, row locks, temporary holds, and unique constraints prevent two customers from purchasing the same seat.

The system should be tested under concurrent purchase requests, payment failures, expired holds, and application or database failures before it is used for a major ticket sale.
