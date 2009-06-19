require 'abstract_unit'
require 'active_support/ruby/shim'
require 'initializer'

class InitializerRunnerTest < ActiveSupport::TestCase

  def setup
    @runner = Rails::Initializer::Runner.new
  end

  test "A new runner can be created" do
    assert @runner
  end

  test "The initializers actually get run when the runner is run" do
    state = nil

    @runner.add :foo do
      run { state = true }
    end

    @runner.run
    assert state
  end

  test "By default, initializers get run in the order that they are added" do
    state = []

    @runner.add :first do
      run { state << :first }
    end

    @runner.add :second do
      run { state << :second }
    end

    @runner.run
    assert_equal [:first, :second], state
  end

  test "Raises an exception if :before or :after are specified, but don't exist" do
    assert_raise(Rails::Initializer::Error) do
      @runner.add(:fail, :before => :whale) { 1 }
    end

    assert_raise(Rails::Initializer::Error) do
      @runner.add(:fail, :after => :whale) { 1 }
    end
  end

  test "When adding an initializer, specifying :after allows you to move an initializer after another" do
    state = []

    @runner.add :first do
      run { state << :first }
    end

    @runner.add :second do
      run { state << :second }
    end

    @runner.add :third, :after => :first do
      run { state << :third }
    end

    @runner.run
    assert_equal [:first, :third, :second], state
  end

  test "An initializer can be deleted" do
    state = []

    @runner.add :first do
      run { state << :first }
    end

    @runner.add :second do
      run { state << :second }
    end

    @runner.delete(:second)

    @runner.run
    assert_equal [:first], state
  end

  test "A runner can be initialized with an existing runner, which it copies" do
    state = []

    @runner.add :first do
      run { state << :first }
    end

    @runner.add :second do
      run { state << :second }
    end

    Rails::Initializer::Runner.new(@runner).run
    assert_equal [:first, :second], state
  end

  test "A child runner can be still be modified without modifying the parent" do
    state = []

    @runner.add :first do
      run { state << :first }
    end

    @runner.add :second do
      run { state << :second }
    end

    new_runner = Rails::Initializer::Runner.new(@runner)
    new_runner.add :trois do
      run { state << :trois }
    end
    new_runner.delete(:second)

    new_runner.run
    assert_equal [:first, :trois], state
    state.clear
    @runner.run
    assert_equal [:first, :second], state
  end

  test "A child runner that is modified does not modify any other children of the same parent" do
    state = []

    @runner.add :first do
      run { state << :first }
    end

    @runner.add :second do
      run { state << :second }
    end

    child_one = Rails::Initializer::Runner.new(@runner)
    child_two = Rails::Initializer::Runner.new(@runner)

    child_one.delete(:second)
    child_two.run

    assert_equal [:first, :second], state
  end

  test "It does not run the initializer block immediately" do
    state = []
    @runner.add :first do
      state << :first
    end

    assert_equal [], state
  end

  test "It runs the block when the runner is run" do
    state = []
    @runner.add :first do
      state << :first
    end

    @runner.run
    assert_equal [:first], state
  end

end