CREATE TABLE 'accounts' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'firm_id' INTEGER DEFAULT NULL,
  'credit_limit' INTEGER DEFAULT NULL
);

CREATE TABLE 'funny_jokes' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'name' TEXT DEFAULT NULL
);

CREATE TABLE 'companies' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'type' VARCHAR(255) DEFAULT NULL,
  'ruby_type' VARCHAR(255) DEFAULT NULL,
  'firm_id' INTEGER DEFAULT NULL,
  'name' TEXT DEFAULT NULL,
  'client_of' INTEGER DEFAULT NULL,
  'rating' INTEGER DEFAULT 1
);


CREATE TABLE 'topics' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'title' VARCHAR(255) DEFAULT NULL,
  'author_name' VARCHAR(255) DEFAULT NULL,
  'author_email_address' VARCHAR(255) DEFAULT NULL,
  'written_on' DATETIME DEFAULT NULL,
  'bonus_time' TIME DEFAULT NULL,
  'last_read' DATE DEFAULT NULL,
  'content' TEXT,
  'approved' boolean DEFAULT 't',
  'replies_count' INTEGER DEFAULT 0,
  'parent_id' INTEGER DEFAULT NULL,
  'type' VARCHAR(255) DEFAULT NULL
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
  'name' TEXT DEFAULT NULL,
  'type' VARCHAR(255) DEFAULT NULL
);

CREATE TABLE 'developers_projects' (
  'developer_id' INTEGER NOT NULL,
  'project_id' INTEGER NOT NULL,
  'joined_on' DATE DEFAULT NULL,
  'access_level' INTEGER DEFAULT 1
);


CREATE TABLE 'orders' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'name' VARCHAR(255) DEFAULT NULL,
  'billing_customer_id' INTEGER DEFAULT NULL,
  'shipping_customer_id' INTEGER DEFAULT NULL
);

CREATE TABLE 'customers' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'name' VARCHAR(255) DEFAULT NULL,
  'balance' INTEGER DEFAULT 0,
  'address_street' TEXT DEFAULT NULL,
  'address_city' TEXT DEFAULT NULL,
  'address_country' TEXT DEFAULT NULL,
  'gps_location' TEXT DEFAULT NULL
);

CREATE TABLE 'movies' (
  'movieid' INTEGER PRIMARY KEY NOT NULL,
  'name' VARCHAR(255) DEFAULT NULL
);

CREATE TABLE subscribers (
 'nick' VARCHAR(255) PRIMARY KEY NOT NULL,
 'name' VARCHAR(255) DEFAULT NULL
);

CREATE TABLE 'booleantests' (
  'id' INTEGER PRIMARY KEY NOT NULL,
  'value' INTEGER DEFAULT NULL
);

CREATE TABLE 'auto_id_tests' (
  'auto_id' INTEGER PRIMARY KEY NOT NULL,
  'value' INTEGER DEFAULT NULL
);

CREATE TABLE 'entrants' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'name' VARCHAR(255) NOT NULL,
  'course_id' INTEGER NOT NULL
);

CREATE TABLE 'colnametests' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'references' INTEGER NOT NULL
);

CREATE TABLE 'mixins' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'parent_id' INTEGER DEFAULT NULL,
  'type' VARCHAR(40) DEFAULT NULL,  
  'pos' INTEGER DEFAULT NULL,
  'lft' INTEGER DEFAULT NULL,
  'rgt' INTEGER DEFAULT NULL,
  'root_id' INTEGER DEFAULT NULL,    
  'created_at' DATETIME DEFAULT NULL,
  'updated_at' DATETIME DEFAULT NULL
);

CREATE TABLE 'people' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'first_name' VARCHAR(40) DEFAULT NULL,
  'lock_version' INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE 'readers' (
    'id' INTEGER NOT NULL PRIMARY KEY,
    'post_id' INTEGER NOT NULL,
    'person_id' INTEGER NOT NULL
);

CREATE TABLE 'binaries' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'data' BLOB DEFAULT NULL
);

CREATE TABLE 'computers' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'developer' INTEGER NOT NULL,
  'extendedWarranty' INTEGER NOT NULL
);

CREATE TABLE 'posts' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'author_id' INTEGER,
  'title' VARCHAR(255) NOT NULL,
  'type' VARCHAR(255) DEFAULT NULL,
  'body' TEXT NOT NULL
);

CREATE TABLE 'comments' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'post_id' INTEGER NOT NULL,
  'type' VARCHAR(255) DEFAULT NULL,
  'body' TEXT NOT NULL
);

CREATE TABLE 'authors' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'name' VARCHAR(255) NOT NULL
);

CREATE TABLE 'tasks' (
  'id' INTEGER NOT NULL PRIMARY KEY,  
  'starting' DATETIME DEFAULT NULL,
  'ending' DATETIME DEFAULT NULL
);

CREATE TABLE 'categories' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'name' VARCHAR(255) NOT NULL,
  'type' VARCHAR(255) DEFAULT NULL
);

CREATE TABLE 'categories_posts' (
  'category_id' INTEGER NOT NULL,
  'post_id' INTEGER NOT NULL
);

CREATE TABLE 'fk_test_has_pk' (
  'id' INTEGER NOT NULL PRIMARY KEY
);

CREATE TABLE 'fk_test_has_fk' (
  'id'    INTEGER NOT NULL PRIMARY KEY,
  'fk_id' INTEGER NOT NULL,

  FOREIGN KEY ('fk_id') REFERENCES 'fk_test_has_pk'('id')
);

CREATE TABLE 'keyboards' (
  'key_number' INTEGER PRIMARY KEY NOT NULL,
  'name' VARCHAR(255) DEFAULT NULL
);

--Altered lock_version column name.
CREATE TABLE 'legacy_things' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'tps_report_number' INTEGER DEFAULT NULL,
  'version' INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE 'numeric_data' (
  'id' INTEGER NOT NULL PRIMARY KEY,
  'bank_balance' DECIMAL(10,2),
  'big_bank_balance' DECIMAL(15,2),
  'world_population' DECIMAL(10),
  'my_house_population' DECIMAL(2),
  'decimal_number_with_default' DECIMAL(3,2) DEFAULT 2.78
);

CREATE TABLE mixed_case_monkeys (
 'monkeyID' INTEGER NOT NULL PRIMARY KEY,
 'fleaCount' INTEGER
);
