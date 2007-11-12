CREATE TABLE 'companies' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'name' TEXT DEFAULT NULL,
  'rating' INTEGER DEFAULT 1
);

CREATE TABLE 'replies' (
  'id' INTEGER PRIMARY KEY NOT NULL, 
  'content' text, 
  'created_at' datetime, 
  'updated_at' datetime, 
  'topic_id' integer,
  'developer_id' integer
);

CREATE TABLE 'topics' (
  'id' INTEGER PRIMARY KEY NOT NULL, 
  'title' varchar(255), 
  'subtitle' varchar(255), 
  'content' text, 
  'created_at' datetime, 
  'updated_at' datetime
);

CREATE TABLE 'developers' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'name' TEXT DEFAULT NULL,
  'salary' INTEGER DEFAULT 70000,
  'created_at' DATETIME DEFAULT NULL,
  'updated_at' DATETIME DEFAULT NULL
);

CREATE TABLE 'projects' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'name' TEXT DEFAULT NULL
);

CREATE TABLE 'developers_projects' (
  'developer_id' INTEGER NOT NULL,
  'project_id' INTEGER NOT NULL,
  'joined_on' DATE DEFAULT NULL,
  'access_level' INTEGER DEFAULT 1
);
