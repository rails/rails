# frozen_string_literal: true

require "cases/helper"
require "models/book"
require "models/clothing_item"

module ActiveRecord
  class InstrumentationTest < ActiveRecord::TestCase
    def setup
      ActiveRecord::Base.schema_cache.add(Book.table_name)
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

    def test_payload_row_count_on_select_all
      10.times { Book.create(name: "row count book 1") }
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("SELECT")
          assert_equal 10, payload[:row_count]
        end
      end
      Book.where(name: "row count book 1").to_a
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_row_count_on_pluck
      10.times { Book.create(name: "row count book 2") }
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("SELECT")
          assert_equal 10, payload[:row_count]
        end
      end
      Book.where(name: "row count book 2").pluck(:name)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_row_count_on_raw_sql
      10.times { Book.create(name: "row count book 3") }
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        if payload[:sql].match?("SELECT")
          assert_equal 10, payload[:row_count]
        end
      end
      ActiveRecord::Base.lease_connection.execute("SELECT * FROM books WHERE name='row count book 3';")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_connection_with_query_cache_disabled
      connection = ClothingItem.lease_connection
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        assert_equal connection, payload[:connection]
      end
      Book.first
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_connection_with_query_cache_enabled
      connection = ClothingItem.lease_connection
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
