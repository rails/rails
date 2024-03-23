# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module ActiveRecord
  class AdapterPreventAccessTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.lease_connection
    end

    def test_preventing_access_predicate
      assert_not ActiveRecord::Base.preventing_access?

      ActiveRecord::Base.while_preventing_access do
        assert_predicate ActiveRecord::Base, :preventing_access?
      end

      assert_not ActiveRecord::Base.preventing_access?
    end

    def test_errors_when_query_is_called_while_preventing_access
      @connection.select_all("SELECT count(*) FROM subscribers")

      ActiveRecord::Base.while_preventing_access do
        assert_raises(ActiveRecord::PreventedAccessError) do
          @connection.select_all("SELECT count(*) FROM subscribers")
        end
      end
    end
  end
end
