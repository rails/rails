# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails", github: "rails/rails", branch: "main"
  gem "sqlite3"
end

require "active_record"
require "minitest/autorun"
require "logger"

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :payments, force: true do |t|
    t.decimal :amount, precision: 10, scale: 0, default: 0, null: false
  end
end

class Payment < ActiveRecord::Base
end

class ChangeAmountToAddScale < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      dir.up do
        change_column :payments, :amount, :decimal, precision: 10, scale: 2, default: 0, null: false
      end

      dir.down do
        change_column :payments, :amount, :decimal, precision: 10, scale: 0, default: 0, null: false
      end
    end
  end
end

class BugTest < Minitest::Test
  def test_migration_up
    ChangeAmountToAddScale.migrate(:up)
    Payment.reset_column_information

    assert_equal "decimal(10,2)", Payment.columns.last.sql_type
  end

  def test_migration_down
    ChangeAmountToAddScale.migrate(:down)
    Payment.reset_column_information

    assert_equal "decimal(10,0)", Payment.columns.last.sql_type
  end
end
