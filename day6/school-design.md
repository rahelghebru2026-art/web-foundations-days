# School Database Design

## 1. Table Descriptions

### Students

The `students` table stores information about students. Each student has a unique `student_id`, a required name, and an email address that must be unique. The primary key identifies each student, while the unique email constraint prevents two students from using the same email address.

### Courses

The `courses` table stores information about courses offered by the school. Each course has a unique `course_id`, a required course name, and a description. The primary key identifies each course.

### Enrolments

The `enrolments` table records which students are enrolled in which courses. It contains its own primary key, `enrolment_id`, along with `student_id` and `course_id` foreign keys. It also stores the student's grade for that course. The combination of `student_id` and `course_id` is unique, preventing the same student from enrolling in the same course more than once.

## 2. Relationships

There is a one-to-many relationship between students and enrolments because one student can have multiple enrolment records, but each enrolment belongs to one student.

There is also a one-to-many relationship between courses and enrolments because one course can have multiple enrolment records, but each enrolment belongs to one course.

Students and courses have a many-to-many relationship: a student can enrol in multiple courses, and a course can have multiple students. The `enrolments` table is necessary to represent this relationship. It connects students to courses through foreign keys and stores additional information, such as grades, for each enrolment.

## 3. Index

I would add an index on `enrolments(course_id)` to help the database find enrolments for a particular course more efficiently. This would improve queries that list students enrolled in a course and support operations that count enrolments by course. The unique constraint on `(student_id, course_id)` already creates an index in SQLite, so a separate index on that same column combination is unnecessary.

## 4. SQL or NoSQL?

I would choose a relational SQL database for this school system. The data has a clear structure, with students, courses, and enrolments connected through primary keys and foreign keys. SQL supports relationships, joins, unique constraints, and transactions, which help maintain data consistency and prevent invalid enrolments. SQLite is suitable for a small school application because it is lightweight and easy to set up. If the application grows to support many concurrent users, a database such as PostgreSQL could be a better choice. A NoSQL database can be useful for flexible or document-oriented data, but its flexibility is not a major advantage for this system's structured relationships.
