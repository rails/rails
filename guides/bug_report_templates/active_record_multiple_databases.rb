# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"

  gem "sqlite3"
end

require "active_record"
require "minitest/autorun"
require "logger"

# Replica databases are included here so you can test role switching. However,
# sqlite3 does not support replication, therefore records written to the writer
# databases will not auto-populate on the replica/reader databases.
ActiveRecord::Base.configurations = {
  development: {
    unsharded_database: {
      adapter: "sqlite3",
      database: ":memory:"
    },
    unsharded_database_replica: {
      adapter: "sqlite3",
      database: ":memory:"
    },
    shard_one: {
      adapter: "sqlite3",
      database: ":memory:"
    },
    shard_one_replica: {
      adapter: "sqlite3",
      database: ":memory:"
    },
    shard_two: {
      adapter: "sqlite3",
      database: ":memory:"
    },
    shard_two_replica: {
      adapter: "sqlite3",
      database: ":memory:"
    },
  }
}

class UnshardedModel < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :unsharded_database, reading: :unsharded_database_replica }
end

class ShardedModel < ActiveRecord::Base
  self.abstract_class = true

  connects_to shards: {
    shard_one: { writing: :shard_one, reading: :shard_one_replica },
    shard_two: { writing: :shard_two, reading: :shard_two_replica }
  }
end

class Post < UnshardedModel
  has_many :comments
end

class Comment < ShardedModel
  belongs_to :post
end

ActiveRecord::Base.logger = Logger.new(STDOUT)

UnshardedModel.connection.create_table(:posts)

ShardedModel.connected_to(shard: :shard_one, role: :writing) do
  ShardedModel.connection.create_table(:comments) do |t|
    t.integer :post_id
  end
end

ShardedModel.connected_to(shard: :shard_two, role: :writing) do
  ShardedModel.connection.create_table(:comments) do |t|
    t.integer :post_id
  end
end

class BugTest < Minitest::Test
  def test_associations_and_shard_switching
    post = Post.create!
    # Comment is a sharded model & ActiveRecord uses the model's first shard as the default shard.
    post.comments << Comment.create!

    assert_equal :shard_one, ShardedModel.default_shard

    ShardedModel.connected_to(shard: :shard_one, role: :writing) do
      assert_equal 1, Comment.count
      assert_equal post.id, Comment.first.post_id
    end

    ShardedModel.connected_to(shard: :shard_two, role: :writing) do
      assert_equal 0, Comment.count

      post.comments << Comment.create!
      post.comments << Comment.create!

      assert_equal 2, post.comments.count
      assert_equal 2, Comment.count
    end
  end
end
