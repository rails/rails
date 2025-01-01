# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"

  gem "sqlite3"
end

require "active_record/railtie"
require "minitest/autorun"

# This connection will do for database-independent bug reports.
ENV["DATABASE_URL"] = "sqlite3::memory:"

class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.logger = Logger.new($stdout)
  config.secret_key_base = "secret_key_base"
end
Rails.application.initialize!

ActiveRecord::Schema.define do
  create_table :payments, force: true do |t|
    t.decimal :amount, precision: 10, scale: 0, default: 0, null: false
  end
end

class Payment < ActiveRecord::Base
end

class ChangeAmountToAddScale < ActiveRecord::Migration::Current # or use a specific version via `Migration[number]`
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

class BugTest < ActiveSupport::TestCase
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
