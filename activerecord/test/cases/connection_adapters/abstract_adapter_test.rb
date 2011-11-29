require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class AbstractAdapterTest < ActiveRecord::TestCase
      def test_in_use?
        adapter = AbstractAdapter.new nil, nil

        # FIXME: change to refute in Rails 4.0 / mt
        assert !adapter.in_use?, 'adapter is not in use'
        assert adapter.lease, 'lease adapter'
        assert adapter.in_use?, 'adapter is in use'
      end
    end
  end
end
