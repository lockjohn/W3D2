
DROP TABLE IF EXISTS questions_likes;
DROP TABLE IF EXISTS replies;
DROP TABLE IF EXISTS questions_follows;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS users;

PRAGMA foreign_keys = ON;

CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname TEXT NOT NULL,
  lname TEXT NOT NULL
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  user_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE questions_follows (
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  question_id INTEGER NOT NULL,
  parent_reply_id INTEGER,
  user_id INTEGER NOT NULL,
  body TEXT NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (parent_reply_id) REFERENCES replies(id)
);

CREATE TABLE questions_likes(
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);


INSERT INTO
users (fname, lname)
VALUES
('John', 'Lockhart'),
('Garbo', 'Cheng');

INSERT INTO
questions (title, body, user_id)
VALUES
('Open File?', 'I cannot open file', (SELECT id FROM users WHERE fname= 'John' AND lname = 'Lockhart')),
('Close File?', 'I forgot how to close a file', (SELECT id FROM users WHERE fname= 'Garbo' AND lname = 'Cheng')),
('blah', 'blah', 2),
('blah', 'blah', 2);

INSERT INTO
questions_follows (user_id, question_id)
VALUES
((SELECT id FROM users WHERE fname= 'John' AND lname = 'Lockhart'), (SELECT id from questions WHERE title = 'Close File?')),
((SELECT id FROM users WHERE fname= 'Garbo' AND lname = 'Cheng'), (SELECT id from questions WHERE title = 'Open File?'));

INSERT INTO
replies (question_id, parent_reply_id, user_id, body)
VALUES
(1,null,2,"here's how you open a file"),
(1,1,1,"thanks!");

INSERT INTO
questions_likes (user_id, question_id)
VALUES
(1,2),
(2,2),
(1,3),
(1,4),
(2,3),
(2,4);
