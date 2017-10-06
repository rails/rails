# frozen_string_literal: true

module ActiveRecord
  module Type
    module Internal
      module Timezone
        def is_utc?
          ActiveRecord::Base.default_timezone == :utc
        end

        def default_timezone
          ActiveRecord::Base.default_timezone
        end
      end
    end
  end
end
