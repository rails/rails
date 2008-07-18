require 'abstract_unit'

uses_mocha 'Memoizable' do
  class MemoizableTest < Test::Unit::TestCase
    class Person
      extend ActiveSupport::Memoizable

      def name
        fetch_name_from_floppy
      end

      memoize :name

      def age
        nil
      end

      def counter
        @counter ||= 0
        @counter += 1
      end

      memoize :age, :counter

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
      counter = @person.counter
      assert_equal 1, @person.counter
      assert_equal 2, @person.counter(:reload)
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

    class Company
      def name
        lookup_name
      end

      def lookup_name
        "37signals"
      end
    end

    def test_object_memoization
      company = Company.new
      company.extend ActiveSupport::Memoizable
      company.memoize :name

      assert_equal "37signals", company.name
      # Mocha doesn't play well with frozen objects
      company.metaclass.instance_eval { define_method(:lookup_name) { b00m } }
      assert_equal "37signals", company.name

      assert_equal true, company.name.frozen?
      company.freeze
      assert_equal true, company.name.frozen?
    end
  end
end
