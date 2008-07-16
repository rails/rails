require 'abstract_unit'

uses_mocha 'Memoizable' do
  class MemoizableTest < Test::Unit::TestCase
    class Person
      include ActiveSupport::Memoizable

      def name
        fetch_name_from_floppy
      end
      memoize :name

      def age
        nil
      end
      memoize :age

      private
        def fetch_name_from_floppy
          "Josh"
        end
    end

    def test_memoization
      person = Person.new
      assert_equal "Josh", person.name

      person.expects(:fetch_name_from_floppy).never
      2.times { assert_equal "Josh", person.name }
    end

    def test_memoized_methods_are_frozen
      person = Person.new
      person.freeze
      assert_equal "Josh", person.name
      assert_equal true, person.name.frozen?
    end

    def test_memoization_frozen_with_nil_value
      person = Person.new
      person.freeze
      assert_equal nil, person.age
    end

    def test_double_memoization
      assert_raise(RuntimeError) { Person.memoize :name }
    end
  end
end
