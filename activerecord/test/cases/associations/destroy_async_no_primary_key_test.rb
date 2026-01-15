# frozen_string_literal: true

require "cases/helper"
require "active_job/base"

class DestroyAsyncNoPrimaryKeyTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  class DummyDestroyJob < ActiveJob::Base
    queue_as :test

    def perform(*); end
  end

  setup do
    @previous_job = ActiveRecord::Base._destroy_association_async_job
    ActiveRecord::Base._destroy_association_async_job = DummyDestroyJob
  end

  teardown do
    ActiveRecord::Base._destroy_association_async_job = @previous_job

    with_lease_connection do |connection|
      connection.drop_table(:owners_no_pk, if_exists: true)
      connection.drop_table(:children_no_pk, if_exists: true)
    end
  end

  def test_has_many_destroy_async_raises_unknown_primary_key_before_enqueue
    with_lease_connection do |connection|
      connection.create_table(:owners_no_pk, force: true) do |t|
        t.string :name
      end

      connection.create_table(:children_no_pk, id: false, force: true) do |t|
        t.integer :owner_id
        t.string :name
      end
    end

    owner_class = Class.new(ActiveRecord::Base) do
      self.table_name = "owners_no_pk"

      has_many :children_no_pk,
        class_name: "DestroyAsyncChildNoPk",
        foreign_key: :owner_id,
        dependent: :destroy_async

      def self.name
        "DestroyAsyncOwnerNoPk"
      end
    end

    child_class = Class.new(ActiveRecord::Base) do
      self.table_name = "children_no_pk"
      self.primary_key = nil

      belongs_to :owner_no_pk,
        class_name: "DestroyAsyncOwnerNoPk",
        foreign_key: :owner_id

      def self.name
        "DestroyAsyncChildNoPk"
      end
    end

    Object.const_set(owner_class.name, owner_class)
    Object.const_set(child_class.name, child_class)

    owner = owner_class.create!(name: "owner")
    child_class.create!(owner_no_pk: owner, name: "c1")

    error = assert_raises(ActiveRecord::UnknownPrimaryKey) { owner.destroy }
    assert_includes error.message, "cannot destroy associated records asynchronously without a primary key"
  ensure
    Object.send(:remove_const, owner_class.name) if Object.const_defined?(owner_class.name)
    Object.send(:remove_const, child_class.name) if Object.const_defined?(child_class.name)
  end

  private
    def with_lease_connection
      connection = ActiveRecord::Base.lease_connection
      yield connection
    ensure
      ActiveRecord::Base.connection_pool.release_connection(connection) if connection
    end
end
