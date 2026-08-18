# frozen_string_literal: true

require "active_support/testing/autorun"
require "rails/autoloaders"

class AutoloadersTest < ActiveSupport::TestCase
  class Loader
    attr_reader :on_load_calls

    def initialize
      @on_load_calls = []
    end

    def on_load(*args, &block)
      @on_load_calls << [args, block]
    end
  end

  setup do
    @main = Loader.new
    @once = Loader.new
    @any = Rails::Autoloaders::Any.new([@main, @once])
  end

  test "any forwards on_load callbacks to all autoloaders" do
    callback = proc { }

    @any.on_load("User", &callback)

    [@main, @once].each do |autoloader|
      args, block = autoloader.on_load_calls.first
      assert_equal ["User"], args
      assert_same callback, block
    end
  end

  test "any forwards on_load callbacks without a constant path" do
    callback = proc { }

    @any.on_load(&callback)

    [@main, @once].each do |autoloader|
      args, block = autoloader.on_load_calls.first
      assert_empty args
      assert_same callback, block
    end
  end

  test "any only exposes callbacks supported across autoloaders" do
    assert_respond_to @any, :on_load
    assert_not_respond_to @any, :on_unload
    assert_not_respond_to @any, :collapse
    assert_not_respond_to @any, :ignore
  end
end
