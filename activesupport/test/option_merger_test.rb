# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/object/with_options"

class OptionMergerTest < ActiveSupport::TestCase
  def setup
    @options = { hello: "world" }
  end

  def test_method_with_options_merges_string_options
    local_options = { "cool" => true }

    with_options(@options) do |o|
      assert_equal local_options, method_with_options(local_options)
      assert_equal @options.merge(local_options), o.method_with_options(local_options)
    end
  end

  def test_method_with_options_merges_options_when_options_are_present
    local_options = { cool: true }

    with_options(@options) do |o|
      assert_equal local_options, method_with_options(local_options)
      assert_equal @options.merge(local_options), o.method_with_options(local_options)
      assert_equal @options.merge(local_options), o.method_with_kwargs(local_options)
      assert_equal @options.merge(local_options), o.method_with_kwargs_only(local_options)
    end
  end

  def test_method_with_options_appends_options_when_options_are_missing
    with_options(@options) do |o|
      assert_equal Hash.new, method_with_options
      assert_equal @options, o.method_with_options
      assert_equal @options, o.method_with_kwargs
      assert_equal @options, o.method_with_kwargs_only
    end
  end

  def test_method_with_options_copies_options_when_options_are_missing
    with_options(@options) do |o|
      assert_not_same @options, o.method_with_options
    end
  end

  def test_method_with_options_allows_to_overwrite_options
    local_options = { hello: "moon" }
    assert_equal @options.keys, local_options.keys

    with_options(@options) do |o|
      assert_equal local_options, method_with_options(local_options)
      assert_equal @options.merge(local_options), o.method_with_options(local_options)
      assert_equal local_options, o.method_with_options(local_options)
    end
    with_options(local_options) do |o|
      assert_equal local_options.merge(@options), o.method_with_options(@options)
    end
  end

  def test_nested_method_with_options_containing_hashes_merge
    with_options conditions: { method: :get } do |outer|
      outer.with_options conditions: { domain: "www" } do |inner|
        expected = { conditions: { method: :get, domain: "www" } }
        assert_equal expected, inner.method_with_options
      end
    end
  end

  def test_nested_method_with_options_containing_hashes_overwrite
    with_options conditions: { method: :get, domain: "www" } do |outer|
      outer.with_options conditions: { method: :post } do |inner|
        expected = { conditions: { method: :post, domain: "www" } }
        assert_equal expected, inner.method_with_options
      end
    end
  end

  def test_nested_method_with_options_containing_hashes_going_deep
    with_options html: { class: "foo", style: { margin: 0, display: "block" } } do |outer|
      outer.with_options html: { title: "bar", style: { margin: "1em", color: "#fff" } } do |inner|
        expected = { html: { class: "foo", title: "bar", style: { margin: "1em", display: "block", color: "#fff" } } }
        assert_equal expected, inner.method_with_options
      end
    end
  end

  def test_nested_method_with_options_using_lambda
    local_lambda = lambda { { lambda: true } }
    with_options(@options) do |o|
      assert_equal @options.merge(local_lambda.call), o.method_with_options(local_lambda).call
    end
  end

  # Needed when counting objects with the ObjectSpace
  def test_option_merger_class_method
    assert_equal ActiveSupport::OptionMerger, ActiveSupport::OptionMerger.new("", "").class
  end

  def test_option_merger_implicit_receiver
    @options.with_options foo: "bar" do
      merge! fizz: "buzz"
    end

    expected = { hello: "world", foo: "bar", fizz: "buzz" }
    assert_equal expected, @options
  end

  private
    def method_with_options(options = {})
      options
    end

    def method_with_kwargs(*args, **options)
      options
    end

    def method_with_kwargs_only(**options)
      options
    end
end
