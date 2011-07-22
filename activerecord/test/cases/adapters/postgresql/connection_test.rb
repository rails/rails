require "cases/helper"

module ActiveRecord
  class PostgresqlConnectionTest < ActiveRecord::TestCase
    def setup
      super
      @connection = ActiveRecord::Base.connection
    end

    def test_encoding
      assert_not_nil @connection.encoding
    end
  end
end
