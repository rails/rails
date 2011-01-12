require "cases/helper"

module ActiveRecord
  module Associations
    class AsssociationProxyTest < ActiveRecord::TestCase
      class FakeOwner
        attr_accessor :new_record
        alias :new_record? :new_record

        def initialize
          @new_record = false
        end
      end

      class FakeReflection < Struct.new(:options, :klass)
        def initialize options = {}, klass = nil
          super
        end

        def check_validity!
          true
        end
      end

      class FakeTarget
      end

      class FakeTargetProxy < AssociationProxy
        def association_scope
          true
        end

        def find_target
          FakeTarget.new
        end
      end

      def test_method_missing_error
        reflection = FakeReflection.new({}, Object.new)
        owner      = FakeOwner.new
        proxy      = FakeTargetProxy.new(owner, reflection)

        exception = assert_raises(NoMethodError) do
          proxy.omg
        end

        assert_match('omg', exception.message)
        assert_match(FakeTarget.name, exception.message)
      end
    end
  end
end
