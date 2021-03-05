# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlDistinctOnTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  class User < ActiveRecord::Base
    self.table_name = "postgresql_users"
    has_many :bikes, dependent: :delete_all
  end

  class Bike < ActiveRecord::Base
    self.table_name = "postgresql_bikes"
    belongs_to :user
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table("postgresql_users", force: true) do |t|
      t.string "name"
      t.integer "age"
      t.json "data", default: {}
    end
    @connection.create_table("postgresql_bikes", force: true) do |t|
      t.integer "user_id"
    end
  end

  teardown do
    @connection.drop_table "postgresql_users", if_exists: true
    @connection.drop_table "postgresql_bikes", if_exists: true
  end

  def test_on_column
    user1, user2, user3 = %w[foo foo bar].map { |name| User.create!(name: name) }
    assert_equal(["bar", "foo"], User.distinct_on(:name).map(&:name).sort)
    [user1, user2, user3].each(&:destroy)
  end

  def test_on_columns
    user1 = User.create!(name: "foo", age: 12)
    user2 = User.create!(name: "foo", age: 13)
    user3 = User.create!(name: "bar", age: 13)
    user4 = User.create!(name: "bar", age: 13)
    assert_equal User.distinct_on(:name, :age).to_a.sort_by(&:id), [user1, user2, user3]
    [user1, user2, user3, user4].each(&:destroy)
  end

  def test_with_eager_load
    user1 = User.create!(name: "foo")
    Bike.create!(user: user1)
    Bike.create!(user: user1)

    user2 = User.create!(name: "bar")
    Bike.create!(user: user1)

    assert_equal User.eager_load(:bikes).distinct_on(:id).sort_by(&:name), [user2, user1]
    [user1, user2].each(&:destroy)
  end
end
