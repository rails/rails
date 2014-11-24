require 'cases/helper'

module ActiveRecord
  class Migration
    class PGChangeSchemaTest < ActiveRecord::TestCase
      attr_reader :connection

      def setup
        super
        @connection = ActiveRecord::Base.connection
        connection.create_table(:strings) do |t|
          t.string :somedate
        end
      end

      def teardown
        connection.drop_table :strings
      end

      def test_change_string_to_date
        connection.change_column :strings, :somedate, :timestamp, using: 'CAST("somedate" AS timestamp)'
      end
    end
  end
end
