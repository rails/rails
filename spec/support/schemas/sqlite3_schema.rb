sql = <<-SQL
  DROP TABLE IF EXISTS users;
  CREATE TABLE users (
    id INTEGER NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
  );

  DROP TABLE IF EXISTS photos;
  CREATE TABLE photos (
    id INTEGER NOT NULL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    camera_id INTEGER NOT NULL
  );
  DROP TABLE IF EXISTS developers;
  CREATE TABLE developers (
    id INTEGER NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    salary INTEGER NOT NULL,
    department VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL
  );
SQL

sql.split(/;/).select(&:present?).each do |sql_statement|
  ActiveRecord::Base.connection.execute sql_statement
end
