# frozen_string_literal: true

require "cases/helper"
require "models/author"
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

    def test_payload_row_count_on_cache
      events = []
      callback = -> (event) do
        payload = event.payload
        events << payload if payload[:sql].include?("SELECT")
      end

      Book.create!(name: "row count book")
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        Book.cache do
          Book.first
          Book.first
        end
      end

      assert_equal 2, events.size
      assert_not events[0][:cached]
      assert events[1][:cached]

      assert_equal 1, events[0][:row_count]
      assert_equal 1, events[1][:row_count]
    end

    def test_payload_affected_rows
      affected_row_values = []

      ActiveSupport::Notifications.subscribed(
        -> (event) { affected_row_values << event.payload[:affected_rows] },
        "sql.active_record",
      ) do
        # The combination of MariaDB + Trilogy returns 0 for affected_rows with
        # INSERT ... RETURNING
        Book.insert_all!([{ name: "One" }, { name: "Two" }, { name: "Three" }, { name: "Four" }], returning: false)

        Book.where(name: ["One", "Two", "Three"]).update_all(status: :published)

        Book.where(name: ["Three", "Four"]).delete_all

        Book.where(name: ["Three", "Four"]).delete_all
      end

      assert_equal [4, 3, 2, 0], affected_row_values
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

    def test_no_instantiation_notification_when_no_records
      author = Author.create!(id: 100, name: "David")

      called = false
      subscriber = ActiveSupport::Notifications.subscribe("instantiation.active_record") do
        called = true
      end

      Author.where(id: 0).to_a
      author.books.to_a

      assert_equal false, called
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end

  module TransactionInSqlActiveRecordPayloadTests
    def test_payload_without_an_open_transaction
      asserted = false

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        if event.payload.fetch(:name) == "Book Count"
          assert_nil event.payload.fetch(:transaction)
          asserted = true
        end
      end

      Book.count

      assert asserted
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    def test_payload_with_an_open_transaction
      asserted = false
      expected_transaction = nil

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        if event.payload.fetch(:name) == "Book Count"
          assert_same expected_transaction, event.payload.fetch(:transaction)
          asserted = true
        end
      end

      Book.transaction do |transaction|
        expected_transaction = transaction
        Book.count
      end

      assert asserted
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end

  class TransactionInSqlActiveRecordPayloadTest < ActiveRecord::TestCase
    include TransactionInSqlActiveRecordPayloadTests
  end

  class TransactionInSqlActiveRecordPayloadNonTransactionalTest < ActiveRecord::TestCase
    include TransactionInSqlActiveRecordPayloadTests

    self.use_transactional_tests = false
  end
end
