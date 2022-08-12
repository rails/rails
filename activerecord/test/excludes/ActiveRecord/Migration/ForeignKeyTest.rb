exclude :test_add_foreign_key_with_if_not_exists_not_set, <<~MSG
  Failure
  Expected /Can't write; duplicate key in table/ to match "Mysql2::Error: Duplicate foreign key constraint name 'fk_rails_78146ddd2e'".
MSG
