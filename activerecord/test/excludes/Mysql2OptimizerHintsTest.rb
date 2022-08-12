exclude :test_optimizer_hints, <<~MSG
  Failure
  Expected EXPLAIN for: SELECT /*+ NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id) */ `posts`.`id` FROM `posts` WHERE `posts`.`author_id` IN (0, 1)
MSG
exclude :test_optimizer_hints_is_sanitized, <<~MSG
  Failure
  Expected EXPLAIN for: SELECT /*+ NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id) */ `posts`.`id` FROM `posts` WHERE `posts`.`author_id` IN (0, 1)
MSG
