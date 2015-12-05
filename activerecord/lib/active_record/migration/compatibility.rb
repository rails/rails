module ActiveRecord
  class Migration
    module Compatibility # :nodoc: all
      V5_0 = Current

      module FourTwoShared
      end

      class V4_2 < V5_0
        # 4.2 is defined as a module because it needs to be shared with
        # Legacy. When the time comes, V5_0 should be defined straight
        # in its class.
        include FourTwoShared
      end

      module Legacy
        include FourTwoShared

        def run(*)
          ActiveSupport::Deprecation.warn \
            "Directly inheriting from ActiveRecord::Migration is deprecated. " \
            "Please specify the Rails release the migration was written for:\n" \
            "\n" \
            "  class #{self.class.name} < ActiveRecord::Migration[4.2]"
          super
        end
      end
    end
  end
end
