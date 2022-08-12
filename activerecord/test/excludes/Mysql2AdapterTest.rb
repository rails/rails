exclude :test_errors_for_bigint_fks_on_string_pk_table_in_create_table, <<~MSG
  Failure
  ActiveRecord::MismatchedForeignKey expected but nothing was raised.
MSG
exclude :test_errors_for_multiple_fks_on_mismatched_types_for_pk_table_in_alter_table, <<~MSG
  Failure
  ActiveRecord::MismatchedForeignKey expected but nothing was raised.
MSG
exclude :test_errors_for_integer_fks_on_bigint_pk_table_in_create_table, <<~MSG
  Failure
  ActiveRecord::MismatchedForeignKey expected but nothing was raised.
MSG
exclude :test_errors_for_bigint_fks_on_integer_pk_table_in_alter_table, <<~MSG
  Failure
  ActiveRecord::MismatchedForeignKey expected but nothing was raised.
MSG
exclude :test_errors_for_bigint_fks_on_integer_pk_table_in_create_table, <<~MSG
  Failure
  ActiveRecord::MismatchedForeignKey expected but nothing was raised.
MSG
