# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails", path: "."

  gem "trilogy"
  gem "benchmark-ips"
  gem "vernier"
  gem "stackprof"
  gem "activerecord-typedstore"
end

require "active_record/railtie"
require "benchmark/ips"
require "vernier"
require "stackprof"
require "json"

# This connection will do for database-independent bug reports.
ENV["DATABASE_URL"] = "sqlite3::memory:"

# Setup Podman MySQL:
# podman pull mysql:latest
# podman run -d --name mysql-dev -p 3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes mysql:latest
# mysql -h 127.0.0.1 -u root -e "CREATE DATABASE IF NOT EXISTS activerecord_test;"
ENV["DATABASE_URL"] = "trilogy://127.0.0.1:3306/activerecord_test?user=root&password="

class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.logger = Logger.new($stdout)
  config.secret_key_base = "secret_key_base"

  config.active_record.encryption.primary_key = "primary_key"
  config.active_record.encryption.deterministic_key = "deterministic_key"
  config.active_record.encryption.key_derivation_salt = "key_derivation_salt"
end
Rails.application.initialize!

# Create bookstore books table without unique indexes
ActiveRecord::Schema.define do
  create_table :books, force: true do |t|
    # Basic fields
    t.bigint :store_id, null: false
    t.string :title, null: false
    t.string :author
    t.string :isbn
    t.string :publisher
    t.date :publication_date
    t.integer :pages

    # Pricing
    t.decimal :price, precision: 10, scale: 2
    t.decimal :cost, precision: 10, scale: 2
    t.decimal :discount_price, precision: 10, scale: 2

    # Inventory fields
    t.integer :quantity
    t.string :warehouse_location
    t.integer :reorder_level
    t.string :supplier

    # Categorization
    t.string :genre
    t.string :category
    t.string :subcategory
    t.string :language, default: "English"

    # Physical properties
    t.string :cover_type
    t.string :format
    t.integer :edition
    t.decimal :weight_oz, precision: 10, scale: 2

    # Flags
    t.boolean :in_print, default: true
    t.boolean :available, default: true
    t.boolean :featured, default: false
    t.boolean :signed_copy, default: false

    # Metadata
    t.text :description
    t.string :series_name
    t.integer :series_number

    # Serialized column
    t.text :dimensions

    # Timestamps
    t.timestamps
    t.datetime :discontinued_at

    # Other fields
    t.integer :reserved_quantity
    t.boolean :has_incoming_shipment
    t.datetime :next_shipment_date
    t.text :awards
  end
end

class Book < ActiveRecord::Base
  serialize :dimensions, coder: JSON
  # serialize :dimensions, coder: YAML
  # typed_store :dimensions, coder: JSON do |s|
  # typed_store :dimensions, coder: YAML do |s|
  #   s.float :width
  #   s.float :height
  #   s.float :depth
  #   s.string :unit
  # end
end

ActiveRecord::Base.logger = nil

TIMES = 10
BATCH_SIZE = 10_000
INSERT_COLUMNS = %i[
  store_id title author isbn publisher publication_date pages
  price cost discount_price
  quantity warehouse_location reorder_level supplier
  genre category subcategory language
  cover_type format edition weight_oz
  in_print available featured signed_copy
  description series_name series_number
  dimensions
  created_at updated_at discontinued_at
  reserved_quantity has_incoming_shipment next_shipment_date awards
].freeze

def truncate_table
  Book.connection.execute("TRUNCATE TABLE books")
end

def raw_sql_insert(payload)
  arel_table = Book.arel_table

  all_attr_values = payload.map do |record|
    INSERT_COLUMNS.map { |col| arel_table.type_cast_for_database(col, record[col]) }
  end

  insert_manager = Arel::InsertManager.new(Book.arel_table)
  insert_manager.into(arel_table)
  insert_manager.columns.concat(INSERT_COLUMNS.map { |col| arel_table[col] })
  insert_manager.values = insert_manager.create_values_list(all_attr_values)
  sql = insert_manager.to_sql
  Book.connection.exec_query(sql, "Book Bulk Insert")
end

def build_book_records(count)
  current_time = Time.now.utc
  store_id = 1

  authors = ["Jane Austen", "Mark Twain", "Virginia Woolf", "Ernest Hemingway", "Toni Morrison"]
  genres = ["Fiction", "Mystery", "Science Fiction", "Biography", "History"]
  publishers = ["Penguin", "Random House", "HarperCollins", "Simon & Schuster", "Macmillan"]

  Array.new(count) do |i|
    {
      store_id: store_id,
      title: "Book Title #{i}",
      author: authors[i % authors.length],
      isbn: "978-0-#{rand(100..999)}-#{rand(10000..99999)}-#{rand(0..9)}",
      publisher: publishers[i % publishers.length],
      publication_date: Date.today - rand(365..3650),
      pages: rand(100..800),
      price: rand(9.99..49.99).round(2),
      cost: rand(5.00..25.00).round(2),
      discount_price: nil,
      quantity: rand(0..100),
      warehouse_location: "A-#{rand(1..50)}-#{rand(1..10)}",
      reorder_level: 5,
      supplier: "Book Distributor Inc",
      genre: genres[i % genres.length],
      category: "General",
      subcategory: nil,
      language: "English",
      cover_type: ["Hardcover", "Paperback"][i % 2],
      format: "Print",
      edition: 1,
      weight_oz: rand(8.0..32.0).round(2),
      in_print: true,
      available: true,
      featured: false,
      signed_copy: false,
      description: "A captivating story that will keep you turning pages.",
      series_name: nil,
      series_number: nil,
      dimensions: {
        width: 6.0,
        height: 9.0,
        depth: 1.5,
        unit: "inches"
      },
      created_at: current_time,
      updated_at: current_time,
      discontinued_at: nil,
      reserved_quantity: 0,
      has_incoming_shipment: false,
      next_shipment_date: nil,
      awards: nil
    }
  end
end

payload = build_book_records(BATCH_SIZE)
3.times do
  Book.insert_all!(payload, record_timestamps: true)
  raw_sql_insert(payload)
end
truncate_table

Benchmark.ips do |x|
  x.report("insert_all!") do
    Book.insert_all!(payload, record_timestamps: true)
  end

  x.report("raw_sql") do
    raw_sql_insert(payload)
  end

  x.compare!(order: :baseline)
end

# Vernier.profile(out: "book_insert_all_vern.json", mode: :wall) do
#   TIMES.times { Book.insert_all!(payload, record_timestamps: true) }
# end
# Vernier.profile(out: "book_raw_sql_vern.json", mode: :wall) do
#   TIMES.times { raw_sql_insert(payload) }
# end

# for speed scope
# profile = StackProf.run(mode: :wall, raw: true) do
#   TIMES.times { Book.insert_all!(payload, record_timestamps: true) }
# end
# File.write("book_insert_all_stack.json", JSON.generate(profile))
# profile = StackProf.run(mode: :wall, raw: true) do
#   TIMES.times { raw_sql_insert(payload) }
# end
# File.write("book_raw_sql_stack.json", JSON.generate(profile))
truncate_table
