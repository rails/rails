require "cases/helper"

module ActiveRecord
  class PostgresqlConnectionTest < ActiveRecord::TestCase
    class NonExistentTable < ActiveRecord::Base
    end

    def setup
      super
      @connection = ActiveRecord::Base.connection
    end

    def test_encoding
      assert_not_nil @connection.encoding
    end

    # Ensure, we can set connection params using the example of Generic
    # Query Optimizer (geqo). It is 'on' per default.
    def test_connection_options
      params = ActiveRecord::Base.connection_config.dup
      params[:options] = "-c geqo=off"
      NonExistentTable.establish_connection(params)

      # Verify the connection param has been applied.
      expect = NonExistentTable.connection.query('show geqo').first.first
      assert_equal 'off', expect
    end
  end
end
