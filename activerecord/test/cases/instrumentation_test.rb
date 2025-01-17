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

      notification = capture_notifications("sql.active_record") { Book.first }
        .find { _1.payload[:sql].match?("SELECT") }

      assert_equal "Book Load", notification.payload[:name]
    end

    def test_payload_name_on_create
      notification = capture_notifications("sql.active_record") { Book.create(name: "test book") }
        .find { _1.payload[:sql].match?("INSERT") }

      assert_equal "Book Create", notification.payload[:name]
    end

    def test_payload_name_on_update
      book = Book.create(name: "test book", format: "paperback")

      notification = capture_notifications("sql.active_record") { book.update_attribute(:format, "ebook") }
        .find { _1.payload[:sql].match?("UPDATE") }

      assert_equal "Book Update", notification.payload[:name]
    end

    def test_payload_name_on_update_all
      notification = capture_notifications("sql.active_record") { Book.update_all(format: "ebook") }
        .find { _1.payload[:sql].match?("UPDATE") }

      assert_equal "Book Update All", notification.payload[:name]
    end

    def test_payload_name_on_eager_load
      ActiveRecord::Base.schema_cache.add(Author.table_name)
      notification = capture_notifications("sql.active_record") { Book.eager_load(:author).to_a }
      assert_equal "Book Eager Load", notification.first.payload[:name]
    end

    def test_payload_name_on_destroy
      book = Book.create(name: "test book")

      notification = capture_notifications("sql.active_record") { book.destroy }
        .find { _1.payload[:sql].match?("DELETE") }

      assert_equal "Book Destroy", notification.payload[:name]
    end

    def test_payload_name_on_delete_all
      notification = capture_notifications("sql.active_record") { Book.delete_all }
        .find { _1.payload[:sql].match?("DELETE") }

      assert_equal "Book Delete All", notification.payload[:name]
    end

    def test_payload_name_on_pluck
      notification = capture_notifications("sql.active_record") { Book.pluck(:name) }
        .find { _1.payload[:sql].match?("SELECT") }

      assert_equal "Book Pluck", notification.payload[:name]
    end

    def test_payload_name_on_count
      notification = capture_notifications("sql.active_record") { Book.count }
        .find { _1.payload[:sql].match?("SELECT") }

      assert_equal "Book Count", notification.payload[:name]
    end

    def test_payload_name_on_grouped_count
      notification = capture_notifications("sql.active_record") { Book.group(:status).count }
        .find { _1.payload[:sql].match?("SELECT") }

      assert_equal "Book Count", notification.payload[:name]
    end

    def test_payload_row_count_on_select_all
      10.times { Book.create(name: "row count book 1") }

      notification = capture_notifications("sql.active_record") { Book.where(name: "row count book 1").to_a }
        .find { _1.payload[:sql].match?("SELECT") }

      assert_equal 10, notification.payload[:row_count]
    end

    def test_payload_row_count_on_pluck
      10.times { Book.create(name: "row count book 2") }

      notification = capture_notifications("sql.active_record") { Book.where(name: "row count book 2").pluck(:name) }
        .find { _1.payload[:sql].match?("SELECT") }

      assert_equal 10, notification.payload[:row_count]
    end

    def test_payload_row_count_on_raw_sql
      10.times { Book.create(name: "row count book 3") }

      notification = capture_notifications("sql.active_record") do
        ActiveRecord::Base.lease_connection.execute("SELECT * FROM books WHERE name='row count book 3';")
      end.find { _1.payload[:sql].match?("SELECT") }

      assert_equal 10, notification.payload[:row_count]
    end

    def test_payload_row_count_on_cache
      Book.create!(name: "row count book")

      notifications = capture_notifications("sql.active_record") do
        Book.cache do
          Book.first
          Book.first
        end
      end

      payloads = notifications.select { _1.payload[:sql].match?("SELECT") }.map(&:payload)

      assert_equal 2, payloads.size
      assert_not payloads[0][:cached]
      assert payloads[1][:cached]
      assert_equal 1, payloads[0][:row_count]
      assert_equal 1, payloads[1][:row_count]
    end

    def test_payload_connection_with_query_cache_disabled
      assert_notification("sql.active_record", connection: ClothingItem.lease_connection) { Book.first }
    end

    def test_payload_connection_with_query_cache_enabled
      connection = ClothingItem.lease_connection

      notifications = capture_notifications("sql.active_record") do
        Book.cache do
          Book.first
          Book.first
        end
      end

      payloads = notifications.select { _1.payload[:sql].match?("SELECT") }.map(&:payload)

      assert_equal 2, payloads.size
      assert_equal connection, payloads.first[:connection]
      assert_equal connection, payloads.second[:connection]
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

    def test_no_instantiation_notification_when_no_records
      author = Author.create!(id: 100, name: "David")

      assert_no_notifications("instantiation.active_record") do
        Author.where(id: 0).to_a
        author.books.to_a
      end
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
