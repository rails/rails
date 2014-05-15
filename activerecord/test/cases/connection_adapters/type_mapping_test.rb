require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    module Type
      class TypeMappingTest < ActiveRecord::TestCase
        def test_default_type
          mapping = TypeMapping.new

          assert_kind_of Value, mapping.lookup(:undefined)
        end

        def test_registering_types
          boolean = Boolean.new
          mapping = TypeMapping.new

          mapping.register_type(/boolean/i, boolean)

          assert_equal mapping.lookup('boolean'), boolean
        end

        def test_overriding_registered_types
          time = Time.new
          timestamp = Timestamp.new
          mapping = TypeMapping.new

          mapping.register_type(/time/i, time)
          mapping.register_type(/time/i, timestamp)

          assert_equal mapping.lookup('time'), timestamp
        end

        def test_fuzzy_lookup
          string = String.new
          mapping = TypeMapping.new

          mapping.register_type(/varchar/i, string)

          assert_equal mapping.lookup('varchar(20)'), string
        end

        def test_aliasing_types
          string = String.new
          mapping = TypeMapping.new

          mapping.register_type(/string/i, string)
          mapping.alias_type(/varchar/i, 'string')

          assert_equal mapping.lookup('varchar'), string
        end

        def test_changing_type_changes_aliases
          time = Time.new
          timestamp = Timestamp.new
          mapping = TypeMapping.new

          mapping.register_type(/timestamp/i, time)
          mapping.alias_type(/datetime/i, 'timestamp')
          mapping.register_type(/timestamp/i, timestamp)

          assert_equal mapping.lookup('datetime'), timestamp
        end

        def test_register_proc
          string = String.new
          binary = Binary.new
          mapping = TypeMapping.new

          mapping.register_type(/varchar/i) do |type|
            if type.include?('(')
              string
            else
              binary
            end
          end

          assert_equal mapping.lookup('varchar(20)'), string
          assert_equal mapping.lookup('varchar'), binary
        end

        def test_requires_value_or_block
          mapping = TypeMapping.new

          assert_raises(ArgumentError) do
            mapping.register_type(/only key/i)
          end
        end
      end
    end
  end
end
