require 'cases/helper'

if ActiveRecord::Base.connection.supports_foreign_keys?
module ActiveRecord
  class Migration
    class ForeignKeyTest < ActiveRecord::TestCase
      class Rocket < ActiveRecord::Base
      end

      class Astronaut < ActiveRecord::Base
      end

      setup do
        @connection = ActiveRecord::Base.connection
        @connection.create_table "rockets" do |t|
          t.string :name
        end

        @connection.create_table "astronauts" do |t|
          t.string :name
          t.references :rocket
        end
      end

      def test_add_foreign_key
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"

        assert_raises ActiveRecord::InvalidForeignKey do
          Astronaut.create rocket_id: 33
        end
      end

      def test_remove_foreign_key
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"
        @connection.remove_foreign_key :astronauts, column: "rocket_id"

        Astronaut.create rocket_id: 33
      end

      def test_remove_foreign_key_by_name
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk"
        @connection.remove_foreign_key :astronauts, name: "fancy_named_fk"

        Astronaut.create rocket_id: 33
      end
    end
  end
end
end
