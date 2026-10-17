-- Day 6 Assignment: School Database
-- Database: SQLite

-- Enable foreign key enforcement in SQLite.
PRAGMA foreign_keys = ON;

-- Drop existing tables so this script can be rerun safely.
-- Drop the child table first because it references the parent tables.
DROP TABLE IF EXISTS enrolments;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;


-- 1. CREATE TABLES

-- Students table: stores student information.
CREATE TABLE students (
    student_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);

-- Courses table: stores course information.
CREATE TABLE courses (
    course_id INTEGER PRIMARY KEY,
    course_name TEXT NOT NULL,
    description TEXT NOT NULL
);

-- Enrolments table: connects students to courses.
-- It also stores the grade each student receives.
CREATE TABLE enrolments (
    enrolment_id INTEGER PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    grade TEXT,

    FOREIGN KEY (student_id)
        REFERENCES students(student_id),

    FOREIGN KEY (course_id)
        REFERENCES courses(course_id),

    UNIQUE (student_id, course_id)
);


-- 2. INSERT SAMPLE DATA

-- Add at least 3 students.
INSERT INTO students (student_id, name, email)
VALUES
    (1, 'Amina Yusuf', 'amina@example.com'),
    (2, 'David Bekele', 'david@example.com'),
    (3, 'Sara Ahmed', 'sara@example.com');


-- Add at least 3 courses.
INSERT INTO courses (course_id, course_name, description)
VALUES
    (1, 'Python Programming', 'Introduction to Python programming'),
    (2, 'Database Systems', 'Introduction to relational databases'),
    (3, 'Web Development', 'HTML, CSS and JavaScript fundamentals');


-- Add at least 5 enrolments.
INSERT INTO enrolments
    (enrolment_id, student_id, course_id, grade)
VALUES
    (1, 1, 1, 'A'),
    (2, 1, 2, 'B'),
    (3, 2, 1, 'B'),
    (4, 2, 3, 'A'),
    (5, 3, 2, 'A');


-- 3. REQUIRED QUERIES

-- Query 1: Find all courses taken by one student, by name.
-- Example: Amina Yusuf
SELECT
    students.name AS student_name,
    courses.course_name
FROM students
JOIN enrolments
    ON students.student_id = enrolments.student_id
JOIN courses
    ON enrolments.course_id = courses.course_id
WHERE students.name = 'Amina Yusuf';


-- Query 2: Find all students enrolled in one course.
-- Example: Python Programming
SELECT
    students.name AS student_name,
    courses.course_name
FROM students
JOIN enrolments
    ON students.student_id = enrolments.student_id
JOIN courses
    ON enrolments.course_id = courses.course_id
WHERE courses.course_name = 'Python Programming';


-- Query 3: Count the number of students per course.
-- LEFT JOIN ensures courses with zero students are included.
SELECT
    courses.course_name,
    COUNT(enrolments.student_id) AS student_count
FROM courses
LEFT JOIN enrolments
    ON courses.course_id = enrolments.course_id
GROUP BY
    courses.course_id,
    courses.course_name
ORDER BY courses.course_name;


-- Query 4: Find students who have no enrolments.
SELECT
    students.student_id,
    students.name,
    students.email
FROM students
LEFT JOIN enrolments
    ON students.student_id = enrolments.student_id
WHERE enrolments.student_id IS NULL;


-- Query 5: Update one enrolment's grade.
-- Change Amina Yusuf's Database Systems grade to A.
UPDATE enrolments
SET grade = 'A'
WHERE student_id = (
    SELECT student_id
    FROM students
    WHERE name = 'Amina Yusuf'
)
AND course_id = (
    SELECT course_id
    FROM courses
    WHERE course_name = 'Database Systems'
);

-- Verify the grade update.
SELECT
    students.name AS student_name,
    courses.course_name,
    enrolments.grade
FROM enrolments
JOIN students
    ON enrolments.student_id = students.student_id
JOIN courses
    ON enrolments.course_id = courses.course_id
WHERE students.name = 'Amina Yusuf'
AND courses.course_name = 'Database Systems';
