exclude :test_foreign_key_violations_on_insert_are_translated_to_specific_exception, <<~MSG
  Failure
  ActiveRecord::InvalidForeignKey expected but nothing was raised.
MSG
exclude :test_foreign_key_violations_on_delete_are_translated_to_specific_exception, <<~MSG
  Failure
  ActiveRecord::InvalidForeignKey expected but nothing was raised.
MSG
exclude :test_foreign_key_violations_are_translated_to_specific_exception_with_validate_false, <<~MSG
  Failure
  ActiveRecord::InvalidForeignKey expected but nothing was raised.
MSG
