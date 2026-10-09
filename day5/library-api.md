# Library Books REST API Design

## Overview

The Library Books API allows users to view, create, update, delete, and search for books.

Base URL: `/api/books`

## Endpoints

### 1. List All Books

* **Method:** GET
* **Path:** `/api/books`
* **Description:** Returns a list of all books in the library.
* **Success status code:** `200 OK`
* **Example request body:** None required.

### 2. Get One Book

* **Method:** GET
* **Path:** `/api/books/:id`
* **Description:** Returns the details of a book with the specified ID.
* **Success status code:** `200 OK`
* **Example request body:** None required.

Example path: `/api/books/5`

### 3. Create a Book

* **Method:** POST
* **Path:** `/api/books`
* **Description:** Creates a new book in the library.
* **Success status code:** `201 Created`
* **Example request body:**

```json
{
  "title": "Introduction to Python",
  "author": "Jane Smith",
  "publishedYear": 2024
}
```

### 4. Update a Book

* **Method:** PUT
* **Path:** `/api/books/:id`
* **Description:** Updates an existing book with the specified ID.
* **Success status code:** `200 OK`
* **Example request body:**

```json
{
  "title": "Advanced Python Programming",
  "author": "Jane Smith",
  "publishedYear": 2025
}
```

### 5. Delete a Book

* **Method:** DELETE
* **Path:** `/api/books/:id`
* **Description:** Deletes the book with the specified ID.
* **Success status code:** `204 No Content`
* **Example request body:** None required.

### 6. List Books by Author

* **Method:** GET
* **Path:** `/api/books?author=Jane%20Smith`
* **Description:** Returns all books written by the specified author.
* **Success status code:** `200 OK`
* **Example request body:** None required.

## Error Responses

### 400 Bad Request

* **Description:** The request contains invalid data or parameters.
* **Example:** A client tries to create a book without the required title or author.

### 404 Not Found

* **Description:** The requested resource does not exist.
* **Example:** A client requests `/api/books/999`, but no book with ID `999` exists.
