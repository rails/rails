# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "models/post"
require "models/author"

class AsyncPreloaderTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  fixtures :authors, :posts

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_async_select_all
    ActiveRecord::Base.asynchronous_queries_tracker.start_session

    author = authors(:david)
    preloader = ActiveRecord::Associations::Preloader.new(records: [author], associations: [:thinking_posts, :welcome_posts])

    payloads = []
    callback = lambda do |name, started, finished, unique_id, payload|
      next if payload[:name].nil? || payload[:name] == "SCHEMA"
      payloads << payload
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      preloader.call(async: true)
    end

    assert_equal 2, payloads.size

    assert_no_queries do
      author.thinking_posts.to_a
      author.welcome_posts.to_a
    end

  ensure
    ActiveRecord::Base.asynchronous_queries_tracker.finalize_session
  end
end
