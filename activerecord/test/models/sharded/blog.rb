# frozen_string_literal: true

# Models under `Sharded` namespace represent an application that can be sharded by a `blog_id` column.
# `Blog` model plays the role of a tenant in the application.
# Being sharded by the `blog_id` means that queries to the database include the `blog_id` column in the clauses
# which serves as a sharding key allows presumed sharding implementation to route the query to a correct shard.

module Sharded
  class Blog < ActiveRecord::Base
    self.table_name = :sharded_blogs
  end
end
