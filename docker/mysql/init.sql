CREATE USER 'rails'@'%';
GRANT ALL PRIVILEGES ON activerecord_unittest.* to 'rails'@'%';
GRANT ALL PRIVILEGES ON activerecord_unittest2.* to 'rails'@'%';
GRANT ALL PRIVILEGES ON inexistent_activerecord_unittest.* to 'rails'@'%';
