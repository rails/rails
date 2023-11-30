# frozen_string_literal: true

require "cases/helper"
require "models/person"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlersMultiDbAssociationTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :people

      class SecondaryBase < ActiveRecord::Base
        self.abstract_class = true
      end

      class House < SecondaryBase
        has_many :residencies
        has_many :persons, through: :residencies
      end

      class Residency < SecondaryBase
        belongs_to :house
        belongs_to :person
      end

      def test_associations_with_multi_db_connections_do_not_do_join_query
        SecondaryBase.connects_to database: { writing: { database: ":memory:", adapter: "sqlite3" } }

        House.connection.execute("CREATE TABLE `houses` (id INTEGER PRIMARY KEY NOT NULL)")
        Residency.connection.execute("CREATE TABLE `residencies` (id INTEGER PRIMARY KEY NOT NULL, person_id INTEGER NOT NULL, house_id INTEGER NOT NULL)")

        house = House.create!
        person = Person.first
        Residency.create!(house: house, person: person)

        assert_queries(2) do
          assert_equal house.persons.first, person
        end
      end
    end
  end
end
