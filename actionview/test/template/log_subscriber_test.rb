require "abstract_unit"
require "active_support/log_subscriber/test_helper"
require "action_view/log_subscriber"
require "controller/fake_models"

class AVLogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super
    view_paths = ActionController::Base.view_paths
    lookup_context = ActionView::LookupContext.new(view_paths, {}, ["test"])
    renderer = ActionView::Renderer.new(lookup_context)
    @view = ActionView::Base.new(renderer, {})
    ActionView::LogSubscriber.attach_to :action_view
    unless Rails.respond_to?(:root)
      @defined_root = true
      def Rails.root; :defined_root; end # Minitest `stub` expects the method to be defined.
    end
  end

  def teardown
    super
    ActiveSupport::LogSubscriber.log_subscribers.clear
    # We need to undef `root`, RenderTestCases don't want this to be defined
    Rails.instance_eval { undef :root } if @defined_root
  end

  def set_logger(logger)
    ActionView::Base.logger = logger
  end

  def test_render_file_template
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(:file => "test/hello_world")
      wait

      assert_equal 2, @logger.logged(:info).size
      assert_match(/Rendering test\/hello_world\.erb/, @logger.logged(:info).first)
      assert_match(/Rendered test\/hello_world\.erb/, @logger.logged(:info).last)
    end
  end

  def test_render_text_template
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(:text => "TEXT")
      wait

      assert_equal 2, @logger.logged(:info).size
      assert_match(/Rendering text template/, @logger.logged(:info).first)
      assert_match(/Rendered text template/, @logger.logged(:info).last)
    end
  end

  def test_render_inline_template
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(:inline => "<%= 'TEXT' %>")
      wait

      assert_equal 2, @logger.logged(:info).size
      assert_match(/Rendering inline template/, @logger.logged(:info).first)
      assert_match(/Rendered inline template/, @logger.logged(:info).last)
    end
  end

  def test_render_partial_template
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(:partial => "test/customer")
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered test\/_customer.erb/, @logger.logged(:info).last)
    end
  end

  def test_render_partial_with_implicit_path
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(Customer.new("david"), :greeting => "hi")
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered customers\/_customer\.html\.erb/, @logger.logged(:info).last)
    end
  end

  def test_render_collection_template
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render(:partial => "test/customer", :collection => [ Customer.new("david"), Customer.new("mary") ])
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered collection of test\/_customer.erb \[2 times\]/, @logger.logged(:info).last)
    end
  end

  def test_render_collection_with_implicit_path
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render([ Customer.new("david"), Customer.new("mary") ], :greeting => "hi")
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered collection of customers\/_customer\.html\.erb \[2 times\]/, @logger.logged(:info).last)
    end
  end

  def test_render_collection_template_without_path
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      @view.render([ GoodCustomer.new("david"), Customer.new("mary") ], :greeting => "hi")
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered collection of templates/, @logger.logged(:info).last)
    end
  end

  def test_render_collection_with_cached_set
    Rails.stub(:root, File.expand_path(FIXTURE_LOAD_PATH)) do
      def @view.view_cache_dependencies; []; end
      def @view.fragment_cache_key(*); "ahoy `controller` dependency"; end

      @view.render(partial: "customers/customer", collection: [ Customer.new("david"), Customer.new("mary") ], cached: true,
        locals: { greeting: "hi" })
      wait

      assert_equal 1, @logger.logged(:info).size
      assert_match(/Rendered collection of customers\/_customer\.html\.erb \[0 \/ 2 cache hits\]/, @logger.logged(:info).last)
    end
  end
end
