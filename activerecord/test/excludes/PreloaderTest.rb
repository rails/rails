exclude :test_preload_with_instance_dependent_through_scope, <<~MSG
  Failure
  --- expected
MSG
exclude :test_preload_with_instance_dependent_scope, <<~MSG
  Failure
  --- expected
MSG
exclude :test_preload_with_through_instance_dependent_scope, <<~MSG
  Failure
  2 instead of 3 queries were executed.
MSG
