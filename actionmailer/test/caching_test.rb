# frozen_string_literal: true

require "fileutils"
require "abstract_unit"
require "mailers/base_mailer"
require "mailers/caching_mailer"

CACHE_DIR = "test_cache"
# Don't change '/../temp/' cavalierly or you might hose something you don't want hosed
FILE_STORE_PATH = File.join(__dir__, "/../temp/", CACHE_DIR)

class FragmentCachingMailer < ActionMailer::Base
  abstract!

  def some_action; end
end

class BaseCachingTest < ActiveSupport::TestCase
  def setup
    super
    @store = ActiveSupport::Cache::MemoryStore.new
    @mailer = FragmentCachingMailer.new
    @mailer.perform_caching = true
    @mailer.cache_store = @store
  end
end

class FragmentCachingTest < BaseCachingTest
  def test_read_fragment_with_caching_enabled
    @store.write("views/name", "value")
    assert_equal "value", @mailer.read_fragment("name")
  end

  def test_read_fragment_with_caching_disabled
    @mailer.perform_caching = false
    @store.write("views/name", "value")
    assert_nil @mailer.read_fragment("name")
  end

  def test_fragment_exist_with_caching_enabled
    @store.write("views/name", "value")
    assert @mailer.fragment_exist?("name")
    assert_not @mailer.fragment_exist?("other_name")
  end

  def test_fragment_exist_with_caching_disabled
    @mailer.perform_caching = false
    @store.write("views/name", "value")
    assert_not @mailer.fragment_exist?("name")
    assert_not @mailer.fragment_exist?("other_name")
  end

  def test_write_fragment_with_caching_enabled
    assert_nil @store.read("views/name")
    assert_equal "value", @mailer.write_fragment("name", "value")
    assert_equal "value", @store.read("views/name")
  end

  def test_write_fragment_with_caching_disabled
    assert_nil @store.read("views/name")
    @mailer.perform_caching = false
    assert_equal "value", @mailer.write_fragment("name", "value")
    assert_nil @store.read("views/name")
  end

  def test_expire_fragment_with_simple_key
    @store.write("views/name", "value")
    @mailer.expire_fragment "name"
    assert_nil @store.read("views/name")
  end

  def test_expire_fragment_with_regexp
    @store.write("views/name", "value")
    @store.write("views/another_name", "another_value")
    @store.write("views/primalgrasp", "will not expire ;-)")

    @mailer.expire_fragment(/name/)

    assert_nil @store.read("views/name")
    assert_nil @store.read("views/another_name")
    assert_equal "will not expire ;-)", @store.read("views/primalgrasp")
  end

  def test_fragment_for
    @store.write("views/expensive", "fragment content")
    fragment_computed = false

    view_context = @mailer.view_context

    buffer = "generated till now -> ".html_safe
    buffer << view_context.send(:fragment_for, "expensive") { fragment_computed = true }

    assert_not fragment_computed
    assert_equal "generated till now -> fragment content", buffer
  end

  def test_html_safety
    assert_nil @store.read("views/name")
    content = "value".html_safe
    assert_equal content, @mailer.write_fragment("name", content)

    cached = @store.read("views/name")
    assert_equal content, cached
    assert_equal String, cached.class

    html_safe = @mailer.read_fragment("name")
    assert_equal content, html_safe
    assert_predicate html_safe, :html_safe?
  end
end

class FunctionalFragmentCachingTest < BaseCachingTest
  def setup
    super
    @store = ActiveSupport::Cache::MemoryStore.new
    @mailer = CachingMailer.new
    @mailer.perform_caching = true
    @mailer.cache_store = @store
  end

  def test_fragment_caching
    email = @mailer.fragment_cache
    expected_body = "\"Welcome\""

    assert_match expected_body, email.body.encoded
    assert_match expected_body,
      @store.read("views/caching_mailer/fragment_cache:#{template_digest("caching_mailer/fragment_cache", "html")}/caching")
  end

  def test_fragment_caching_in_partials
    email = @mailer.fragment_cache_in_partials
    expected_body = "Old fragment caching in a partial"
    assert_match(expected_body, email.body.encoded)

    assert_match(expected_body,
      @store.read("views/caching_mailer/_partial:#{template_digest("caching_mailer/_partial", "html")}/caching"))
  end

  def test_skip_fragment_cache_digesting
    email = @mailer.skip_fragment_cache_digesting
    expected_body = "No Digest"

    assert_match expected_body, email.body.encoded
    assert_match expected_body, @store.read("views/no_digest")
  end

  def test_fragment_caching_options
    time = Time.now
    email = @mailer.fragment_caching_options
    expected_body = "No Digest"

    assert_match expected_body, email.body.encoded
    Time.stub(:now, time + 11) do
      assert_nil @store.read("views/no_digest")
    end
  end

  def test_multipart_fragment_caching
    email = @mailer.multipart_cache

    expected_text_body = "\"Welcome text\""
    expected_html_body = "\"Welcome html\""
    encoded_body = email.body.encoded
    assert_match expected_text_body, encoded_body
    assert_match expected_html_body, encoded_body
    assert_match expected_text_body,
                 @store.read("views/text_caching")
    assert_match expected_html_body,
                 @store.read("views/html_caching")
  end

  def test_fragment_cache_instrumentation
    @mailer.enable_fragment_cache_logging = true
    payload = nil

    subscriber = proc do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      payload = event.payload
    end

    ActiveSupport::Notifications.subscribed(subscriber, "read_fragment.action_mailer") do
      @mailer.fragment_cache
    end

    assert_equal "caching_mailer", payload[:mailer]
    assert_equal [ :views, "caching_mailer/fragment_cache:#{template_digest("caching_mailer/fragment_cache", "html")}", :caching ], payload[:key]
  ensure
    @mailer.enable_fragment_cache_logging = true
  end

  private
    def template_digest(name, format)
      ActionView::Digestor.digest(name: name, format: format, finder: @mailer.lookup_context)
    end
end

class CacheHelperOutputBufferTest < BaseCachingTest
  class MockController
    def read_fragment(name, options)
      false
    end

    def write_fragment(name, fragment, options)
      fragment
    end
  end

  def setup
    super
  end

  def test_output_buffer
    output_buffer = ActionView::OutputBuffer.new
    controller = MockController.new
    cache_helper = Class.new do
      def self.controller; end
      def self.output_buffer; end
      def self.output_buffer=; end
    end
    cache_helper.extend(ActionView::Helpers::CacheHelper)

    cache_helper.stub :controller, controller do
      cache_helper.stub :output_buffer, output_buffer do
        assert_called_with cache_helper, :output_buffer=, [output_buffer.class.new(output_buffer)] do
          assert_nothing_raised do
            cache_helper.send :fragment_for, "Test fragment name", "Test fragment", &Proc.new { nil }
          end
        end
      end
    end
  end

  def test_safe_buffer
    output_buffer = ActiveSupport::SafeBuffer.new
    controller = MockController.new
    cache_helper = Class.new do
      def self.controller; end
      def self.output_buffer; end
      def self.output_buffer=; end
    end
    cache_helper.extend(ActionView::Helpers::CacheHelper)

    cache_helper.stub :controller, controller do
      cache_helper.stub :output_buffer, output_buffer do
        assert_called_with cache_helper, :output_buffer=, [output_buffer.class.new(output_buffer)] do
          assert_nothing_raised do
            cache_helper.send :fragment_for, "Test fragment name", "Test fragment", &Proc.new { nil }
          end
        end
      end
    end
  end
end

class ViewCacheDependencyTest < BaseCachingTest
  class NoDependenciesMailer < ActionMailer::Base
  end
  class HasDependenciesMailer < ActionMailer::Base
    view_cache_dependency { "trombone" }
    view_cache_dependency { "flute" }
  end

  def test_view_cache_dependencies_are_empty_by_default
    assert_empty NoDependenciesMailer.new.view_cache_dependencies
  end

  def test_view_cache_dependencies_are_listed_in_declaration_order
    assert_equal %w(trombone flute), HasDependenciesMailer.new.view_cache_dependencies
  end
end
