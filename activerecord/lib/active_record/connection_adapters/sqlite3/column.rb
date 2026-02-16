# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class Column < ConnectionAdapters::Column # :nodoc:
        attr_reader :rowid

        def initialize(*, auto_increment: nil, rowid: false, generated_type: nil, **)
          super
          @auto_increment = auto_increment
          @rowid = rowid
          @generated_type = generated_type
        end

        def auto_increment?
          @auto_increment
        end

        def auto_incremented_by_db?
          auto_increment? || rowid
        end

        def virtual?
          !@generated_type.nil?
        end

        def virtual_stored?
          virtual? && @generated_type == :stored
        end

        def has_default?
          super && !virtual?
        end

        def init_with(coder)
          @auto_increment = coder["auto_increment"]
          super
        end

        def encode_with(coder)
          coder["auto_increment"] = @auto_increment
          super
        end

        def ==(other)
          other.is_a?(Column) &&
            super &&
            auto_increment? == other.auto_increment? &&
            rowid == other.rowid &&
            virtual? == other.virtual?
        end
        alias :eql? :==

        def hash
          [
            Column,
            super,
            @auto_increment,
            @rowid,
            @generated_type,
          ].hash
        end
      end
    end
  end
end
