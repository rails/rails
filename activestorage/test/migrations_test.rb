# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::MigrationsTest < ActiveSupport::TestCase
  setup do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    @connection = ActiveRecord::Base.connection
    @original_options = Rails.configuration.generators.options.deep_dup
  end

  teardown do
    Rails.configuration.generators.options = @original_options
    rerun_migration
    ActiveRecord::Migration.verbose = @original_verbose
  end

  test "migration creates tables with default primary and foreign key types" do
    rerun_migration

    active_storage_tables.each do |table|
      assert_equal :integer, primary_key(table).type

      foreign_keys(table).each do |foreign_key|
        assert_equal :integer, foreign_key.type
      end
    end
  end

  test "migration creates tables with configured primary and foreign key types" do
    Rails.configuration.generators do |g|
      g.orm :active_record, primary_key_type: :string
    end

    rerun_migration

    active_storage_tables.each do |table|
      assert_equal :string, primary_key(table).type

      foreign_keys(table).each do |foreign_key|
        assert_equal :string, foreign_key.type
      end
    end
  end

  private
    def rerun_migration
      CreateActiveStorageTables.migrate(:down)
      CreateActiveStorageTables.migrate(:up)
    end

    def active_storage_tables
      [:active_storage_blobs, :active_storage_attachments, :active_storage_variant_records]
    end

    def primary_key(table)
      @connection.columns(table).find { |c| c.name == "id" }
    end

    def foreign_keys(table)
      columns = @connection.foreign_keys(table).map(&:column)
      @connection.columns(table).select { |c| columns.include?(c.name) }
    end
end
