# frozen_string_literal: true

module ActiveRecord
  module ConnectionHandling
    def fake_legacy_connection(config)
      ConnectionAdapters::FakeLegacyAdapter.new nil, logger
    end
  end

  module ConnectionAdapters
    class FakeLegacyAdapter < AbstractAdapter
      def active?
        true
      end
    end
  end
end
