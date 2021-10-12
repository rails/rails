# frozen_string_literal: true

module ActiveRecord
  module Type
    module Internal
      module Timezone
        def is_utc?
          ActiveRecord.default_timezone == :utc
        end

        def default_timezone
          ActiveRecord.default_timezone
        end
      end
    end
  end
end
