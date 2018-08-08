# frozen_string_literal: true

require "abstract_unit"
require "rails/code_statistics_calculator"

class CodeStatisticsCalculatorTest < ActiveSupport::TestCase
  def setup
    @code_statistics_calculator = CodeStatisticsCalculator.new
  end

  test "calculate statistics using #add_by_file_path" do
    code = <<-RUBY
      def foo
        puts 'foo'
        # bar
      end
    RUBY

    temp_file "stats.rb", code do |path|
      @code_statistics_calculator.add_by_file_path path

      assert_equal 4, @code_statistics_calculator.lines
      assert_equal 3, @code_statistics_calculator.code_lines
      assert_equal 0, @code_statistics_calculator.classes
      assert_equal 1, @code_statistics_calculator.methods
    end
  end

  test "count number of methods in Minitest file" do
    code = <<-RUBY
      class FooTest < ActionController::TestCase
        test 'expectation' do
          assert true
        end

        def test_expectation
          assert true
        end
      end
    RUBY

    temp_file "foo_test.rb", code do |path|
      @code_statistics_calculator.add_by_file_path path
      assert_equal 2, @code_statistics_calculator.methods
    end
  end

  test "add statistics to another using #add" do
    code_statistics_calculator_1 = CodeStatisticsCalculator.new(1, 2, 3, 4)
    @code_statistics_calculator.add(code_statistics_calculator_1)

    assert_equal 1, @code_statistics_calculator.lines
    assert_equal 2, @code_statistics_calculator.code_lines
    assert_equal 3, @code_statistics_calculator.classes
    assert_equal 4, @code_statistics_calculator.methods

    code_statistics_calculator_2 = CodeStatisticsCalculator.new(2, 3, 4, 5)
    @code_statistics_calculator.add(code_statistics_calculator_2)

    assert_equal 3, @code_statistics_calculator.lines
    assert_equal 5, @code_statistics_calculator.code_lines
    assert_equal 7, @code_statistics_calculator.classes
    assert_equal 9, @code_statistics_calculator.methods
  end

  test "accumulate statistics using #add_by_io" do
    code_statistics_calculator_1 = CodeStatisticsCalculator.new(1, 2, 3, 4)
    @code_statistics_calculator.add(code_statistics_calculator_1)

    code = <<-'CODE'
      def foo
        puts 'foo'
      end

      def bar; end
      class A; end
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :rb)

    assert_equal 7, @code_statistics_calculator.lines
    assert_equal 7, @code_statistics_calculator.code_lines
    assert_equal 4, @code_statistics_calculator.classes
    assert_equal 6, @code_statistics_calculator.methods
  end

  test "calculate number of Ruby methods" do
    code = <<-'CODE'
      def foo
        puts 'foo'
      end

      def bar; end

      class Foo
        def bar(abc)
        end
      end
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :rb)

    assert_equal 3, @code_statistics_calculator.methods
  end

  test "calculate Ruby LOCs" do
    code = <<-'CODE'
      def foo
        puts 'foo'
      end

      # def bar; end

      class A < B
      end
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :rb)

    assert_equal 8, @code_statistics_calculator.lines
    assert_equal 5, @code_statistics_calculator.code_lines
  end

  test "calculate number of Ruby classes" do
    code = <<-'CODE'
      class Foo < Bar
        def foo
          puts 'foo'
        end
      end

      class Z; end

      # class A
      # end
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :rb)

    assert_equal 2, @code_statistics_calculator.classes
  end

  test "skip Ruby comments" do
    code = <<-'CODE'
=begin
      class Foo
        def foo
          puts 'foo'
        end
      end
=end

      # class A
      # end
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :rb)

    assert_equal 10, @code_statistics_calculator.lines
    assert_equal 0, @code_statistics_calculator.code_lines
    assert_equal 0, @code_statistics_calculator.classes
    assert_equal 0, @code_statistics_calculator.methods
  end

  test "calculate number of JS methods" do
    code = <<-'CODE'
      function foo(x, y, z) {
        doX();
      }

      $(function () {
        bar();
      })

      var baz = function ( x ) {
      }
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :js)

    assert_equal 3, @code_statistics_calculator.methods
  end

  test "calculate JS LOCs" do
    code = <<-'CODE'
      function foo()
        alert('foo');
      end

      // var b = 2;

      var a = 1;
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :js)

    assert_equal 7, @code_statistics_calculator.lines
    assert_equal 4, @code_statistics_calculator.code_lines
  end

  test "skip JS comments" do
    code = <<-'CODE'
      /*
       * var f = function () {
       1 / 2;
      }
      */

      // call();
      //
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :js)

    assert_equal 8, @code_statistics_calculator.lines
    assert_equal 0, @code_statistics_calculator.code_lines
    assert_equal 0, @code_statistics_calculator.classes
    assert_equal 0, @code_statistics_calculator.methods
  end

  test "calculate number of CoffeeScript methods" do
    code = <<-'CODE'
      square = (x) -> x * x

      math =
        cube: (x) -> x * square x

      fill = (container, liquid = "coffee") ->
        "Filling the #{container} with #{liquid}..."

      $('.shopping_cart').bind 'click', (event) =>
        @customer.purchase @cart
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :coffee)

    assert_equal 4, @code_statistics_calculator.methods
  end

  test "calculate CoffeeScript LOCs" do
    code = <<-'CODE'
      # Assignment:
      number   = 42
      opposite = true

      ###
      CoffeeScript Compiler v1.4.0
      Released under the MIT License
      ###

      # Conditions:
      number = -42 if opposite
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :coffee)

    assert_equal 11, @code_statistics_calculator.lines
    assert_equal 3, @code_statistics_calculator.code_lines
  end

  test "calculate number of CoffeeScript classes" do
    code = <<-'CODE'
      class Animal
        constructor: (@name) ->

        move: (meters) ->
          alert @name + " moved #{meters}m."

      class Snake extends Animal
        move: ->
          alert "Slithering..."
          super 5

      # class Horse
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :coffee)

    assert_equal 2, @code_statistics_calculator.classes
  end

  test "skip CoffeeScript comments" do
    code = <<-'CODE'
###
class Animal
  constructor: (@name) ->

  move: (meters) ->
    alert @name + " moved #{meters}m."
  ###

  # class Horse
  alert 'hello'
    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :coffee)

    assert_equal 10, @code_statistics_calculator.lines
    assert_equal 1, @code_statistics_calculator.code_lines
    assert_equal 0, @code_statistics_calculator.classes
    assert_equal 0, @code_statistics_calculator.methods
  end

  test "count rake tasks" do
    code = <<-'CODE'
      task :test_task do
        puts 'foo'
      end

    CODE

    @code_statistics_calculator.add_by_io(StringIO.new(code), :rake)

    assert_equal 4, @code_statistics_calculator.lines
    assert_equal 3, @code_statistics_calculator.code_lines
    assert_equal 0, @code_statistics_calculator.classes
    assert_equal 0, @code_statistics_calculator.methods
  end

  private
    def temp_file(name, content)
      dir = File.expand_path "fixtures/tmp", __dir__
      path = "#{dir}/#{name}"

      FileUtils.mkdir_p dir
      File.write path, content

      yield path
    ensure
      FileUtils.rm_rf path
    end
end
