# frozen_string_literal: true

require "cases/helper"
require "models/book"

module ActiveRecord
  class InstrumentationTest < ActiveRecord::TestCase
    def test_payload_name_on_load
      Book.create(name: "test book")
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        if event.payload[:sql].match "SELECT"
          assert_equal "Book Load", event.payload[:name]
        end
      end
      Book.first
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_create
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        if event.payload[:sql].match "INSERT"
          assert_equal "Book Create", event.payload[:name]
        end
      end
      Book.create(name: "test book")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_update
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        if event.payload[:sql].match "UPDATE"
          assert_equal "Book Update", event.payload[:name]
        end
      end
      book = Book.create(name: "test book")
      book.update_attribute(:name, "new name")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_update_all
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        if event.payload[:sql].match "UPDATE"
          assert_equal "Book Update All", event.payload[:name]
        end
      end
      Book.create(name: "test book")
      Book.update_all(name: "new name")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def test_payload_name_on_destroy
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        if event.payload[:sql].match "DELETE"
          assert_equal "Book Destroy", event.payload[:name]
        end
      end
      book = Book.create(name: "test book")
      book.destroy
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end
end
