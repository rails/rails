# frozen_string_literal: true

require "cases/helper"
require "models/company"

if ActiveRecord::Base.connection.supports_use_index?
  module ActiveRecord
    class UseIndexTest < ActiveRecord::TestCase
      fixtures :companies

      attr_reader :index_name

      def setup
        connection.add_index(:companies, :firm_name) unless connection.index_exists?(:companies, :firm_name)
        @index_name = :index_companies_on_firm_name
      end

      def test_use_index_on_mysql
        assert_includes Company.where(firm_name: "Gaurish Inc.").use_index(index_name).to_sql, "USE INDEX (#{index_name})"
      end

      def test_unsupported_connection_adapter
        connection.stub(:supports_use_index?, false) do
          company = Company.where(firm_name: "37signals").use_index(index_name)
          assert_equal "37signals", company.first.firm_name
        end
      end

      private

        def connection
          @connection ||= ActiveRecord::Base.connection
        end
    end
  end
end
