require 'abstract_unit'

uses_mocha 'Memoizable' do
  class MemoizableTest < Test::Unit::TestCase
    class Person
      include ActiveSupport::Memoizable

      def name
        fetch_name_from_floppy
      end

      def age
        nil
      end

      def random
        rand(0)
      end

      memoize :name, :age, :random

      private
        def fetch_name_from_floppy
          "Josh"
        end
    end

    def setup
      @person = Person.new
    end

    def test_memoization
      assert_equal "Josh", @person.name

      @person.expects(:fetch_name_from_floppy).never
      2.times { assert_equal "Josh", @person.name }
    end

    def test_reloadable
      random = @person.random
      assert_equal random, @person.random
      assert_not_equal random, @person.random(:reload)
    end

    def test_memoized_methods_are_frozen
      assert_equal true, @person.name.frozen?

      @person.freeze
      assert_equal "Josh", @person.name
      assert_equal true, @person.name.frozen?
    end

    def test_memoization_frozen_with_nil_value
      @person.freeze
      assert_equal nil, @person.age
    end

    def test_double_memoization
      assert_raise(RuntimeError) { Person.memoize :name }
    end
  end
end
