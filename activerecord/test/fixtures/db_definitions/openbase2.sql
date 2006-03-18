CREATE TABLE courses (
  id integer UNIQUE INDEX DEFAULT _rowid,
  name text
)
go
CREATE PRIMARY KEY courses (id)
go