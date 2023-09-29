# frozen_string_literal: true

require "cases/helper"
require "models/book"

module ActiveRecord
  class InstrumentationTest < ActiveRecord::TestCase
    def setup
      ActiveRecord::Base.connection.schema_cache.add(Book.table_name)
    end

    def test_payload_name_on_load
      Book.create(name: "test book")
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("SELECT")
          assert_equal "Book Load", payload[:name]
        end
      end
      Book.first
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_create
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("INSERT")
          assert_equal "Book Create", payload[:name]
        end
      end
      Book.create(name: "test book")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_update
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("UPDATE")
          assert_equal "Book Update", payload[:name]
        end
      end
      book = Book.create(name: "test book", format: "paperback")
      book.update_attribute(:format, "ebook")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_update_all
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("UPDATE")
          assert_equal "Book Update All", payload[:name]
        end
      end
      Book.update_all(format: "ebook")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_destroy
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("DELETE")
          assert_equal "Book Destroy", payload[:name]
        end
      end
      book = Book.create(name: "test book")
      book.destroy
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_delete_all
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("DELETE")
          assert_equal "Book Delete All", payload[:name]
        end
      end
      Book.delete_all
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_pluck
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("SELECT")
          assert_equal "Book Pluck", payload[:name]
        end
      end
      Book.pluck(:name)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_count
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("SELECT")
          assert_equal "Book Count", payload[:name]
        end
      end
      Book.count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_grouped_count
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("SELECT")
          assert_equal "Book Count", payload[:name]
        end
      end
      Book.group(:status).count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_connection_with_query_cache_disabled
      connection = Book.connection
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        assert_equal connection, payload[:connection]
      end
      Book.first
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_connection_with_query_cache_enabled
      connection = Book.connection
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        assert_equal connection, payload[:connection]
      end
      Book.cache do
        Book.first
        Book.first
      end
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end
end
