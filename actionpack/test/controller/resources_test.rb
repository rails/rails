require File.dirname(__FILE__) + '/../abstract_unit'

class ResourcesController < ActionController::Base
  def index() render :nothing => true end
  def rescue_action(e) raise e end
end

class ThreadsController  < ResourcesController; end
class MessagesController < ResourcesController; end
class CommentsController < ResourcesController; end


class ResourcesTest < Test::Unit::TestCase
  def test_should_arrange_actions
    resource = ActionController::Resources::Resource.new(:messages,
      :collection => { :rss => :get, :reorder => :post, :csv => :post },
      :member     => { :rss => :get, :atom => :get, :upload => :post, :fix => :post },
      :new        => { :preview => :get, :draft => :get })

    assert_resource_methods [:rss],                   resource, :collection, :get
    assert_resource_methods [:csv, :reorder],         resource, :collection, :post
    assert_resource_methods [:edit, :rss, :atom],     resource, :member,     :get
    assert_resource_methods [:upload, :fix],          resource, :member,     :post
    assert_resource_methods [:new, :preview, :draft], resource, :new,        :get
  end

  def test_default_restful_routes
    with_restful_routing :messages do
      assert_simply_restful_for :messages
    end
  end

  def test_multiple_default_restful_routes
    with_restful_routing :messages, :comments do
      assert_simply_restful_for :messages
      assert_simply_restful_for :comments
    end
  end

  def test_with_path_prefix
    with_restful_routing :messages, :path_prefix => '/thread/:thread_id' do
      assert_simply_restful_for :messages, :path_prefix => 'thread/5/', :options => { :thread_id => '5' }
    end
  end

  def test_multile_with_path_prefix
    with_restful_routing :messages, :comments, :path_prefix => '/thread/:thread_id' do
      assert_simply_restful_for :messages, :path_prefix => 'thread/5/', :options => { :thread_id => '5' }
      assert_simply_restful_for :comments, :path_prefix => 'thread/5/', :options => { :thread_id => '5' }
    end
  end

  def test_with_collection_action
    rss_options = {:action => 'rss'}
    rss_path    = "/messages;rss"
    actions = { 'a' => :put, 'b' => :post, 'c' => :delete }

    with_restful_routing :messages, :collection => { :rss => :get }.merge(actions) do
      assert_restful_routes_for :messages do |options|
        assert_routing rss_path, options.merge(rss_options)

        actions.each do |action, method|
          assert_recognizes(options.merge(:action => action), :path => "/messages;#{action}", :method => method)
        end
      end

      assert_restful_named_routes_for :messages do |options|
        assert_named_route rss_path, :rss_messages_path, rss_options
        actions.keys.each do |action|
          assert_named_route "/messages;#{action}", "#{action}_messages_path", :action => action
        end
      end
    end
  end

  def test_with_member_action
    [:put, :post].each do |method|
      with_restful_routing :messages, :member => { :mark => method } do
        mark_options = {:action => 'mark', :id => '1'}
        mark_path    = "/messages/1;mark"
        assert_restful_routes_for :messages do |options|
          assert_recognizes(options.merge(mark_options), :path => mark_path, :method => method)
        end

        assert_restful_named_routes_for :messages do |options|
          assert_named_route mark_path, :mark_message_path, mark_options
        end
      end
    end
  end

  def test_with_two_member_actions_with_same_method
    [:put, :post].each do |method|
      with_restful_routing :messages, :member => { :mark => method, :unmark => method } do
        %w(mark unmark).each do |action|
          action_options = {:action => action, :id => '1'}
          action_path    = "/messages/1;#{action}"
          assert_restful_routes_for :messages do |options|
            assert_recognizes(options.merge(action_options), :path => action_path, :method => method)
          end

          assert_restful_named_routes_for :messages do |options|
            assert_named_route action_path, "#{action}_message_path".to_sym, action_options
          end
        end
      end
    end
  end


  def test_with_new_action
    with_restful_routing :messages, :new => { :preview => :post } do
      preview_options = {:action => 'preview'}
      preview_path    = "/messages/new;preview"
      assert_restful_routes_for :messages do |options|
        assert_recognizes(options.merge(preview_options), :path => preview_path, :method => :post)
      end

      assert_restful_named_routes_for :messages do |options|
        assert_named_route preview_path, :preview_new_message_path, preview_options
      end
    end
  end

  def test_override_new_method
    with_restful_routing :messages do
      assert_restful_routes_for :messages do |options|
        assert_recognizes(options.merge(:action => "new"), :path => "/messages/new", :method => :get)
        assert_raises(ActionController::RoutingError) do
          ActionController::Routing::Routes.recognize_path("/messages/new", :method => :post)
        end
      end
    end

    with_restful_routing :messages, :new => { :new => :any } do
      assert_restful_routes_for :messages do |options|
        assert_recognizes(options.merge(:action => "new"), :path => "/messages/new", :method => :post)
        assert_recognizes(options.merge(:action => "new"), :path => "/messages/new", :method => :get)
      end
    end
  end

  def test_nested_restful_routes
    with_routing do |set|
      set.draw do |map|
        map.resources :threads do |map|
          map.resources :messages do |map|
            map.resources :comments
          end
        end
      end

      assert_simply_restful_for :threads
      assert_simply_restful_for :messages,
        :path_prefix => 'threads/1/',
        :options => { :thread_id => '1' }
      assert_simply_restful_for :comments,
        :path_prefix => 'threads/1/messages/2/',
        :options => { :thread_id => '1', :message_id => '2' }
    end
  end

  def test_restful_routes_dont_generate_duplicates
    with_restful_routing :messages do
      routes = ActionController::Routing::Routes.routes
      routes.each do |route|
        routes.each do |r|
          next if route === r # skip the comparison instance
          assert distinct_routes?(route, r), "Duplicate Route: #{route}"
        end
      end
    end
  end

  protected
    def with_restful_routing(*args)
      with_routing do |set|
        set.draw { |map| map.resources(*args) }
        yield
      end
    end

    # runs assert_restful_routes_for and assert_restful_named_routes for on the controller_name and options, without passing a block.
    def assert_simply_restful_for(controller_name, options = {})
      assert_restful_routes_for       controller_name, options
      assert_restful_named_routes_for controller_name, options
    end

    def assert_restful_routes_for(controller_name, options = {})
      (options[:options] ||= {})[:controller] = controller_name.to_s

      collection_path = "/#{options[:path_prefix]}#{controller_name}"
      member_path = "#{collection_path}/1"
      new_path = "#{collection_path}/new"

      with_options(options[:options]) do |controller|
        controller.assert_routing collection_path,            :action => 'index'
        controller.assert_routing "#{collection_path}.xml" ,  :action => 'index', :format => 'xml'
        controller.assert_routing new_path,                   :action => 'new'
        controller.assert_routing member_path,                :action => 'show', :id => '1'
        controller.assert_routing "#{member_path};edit",      :action => 'edit', :id => '1'
        controller.assert_routing "#{member_path}.xml",       :action => 'show', :id => '1', :format => 'xml'
      end

      assert_recognizes(
        options[:options].merge(:action => 'create'),
        :path => collection_path, :method => :post)

      assert_recognizes(
        options[:options].merge(:action => 'update', :id => '1'),
        :path => member_path, :method => :put)

      assert_recognizes(
        options[:options].merge(:action => 'destroy', :id => '1'),
        :path => member_path, :method => :delete)

      yield options[:options] if block_given?
    end

    # test named routes like foo_path and foos_path map to the correct options.
    def assert_restful_named_routes_for(controller_name, singular_name = nil, options = {})
      if singular_name.is_a?(Hash)
        options       = singular_name
        singular_name = nil
      end
      singular_name ||= controller_name.to_s.singularize
      (options[:options] ||= {})[:controller] = controller_name.to_s
      @controller = "#{controller_name.to_s.camelize}Controller".constantize.new
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new
      get :index, options[:options]
      options[:options].delete :action

      full_prefix = "/#{options[:path_prefix]}#{controller_name}"

      assert_named_route "#{full_prefix}",        "#{controller_name}_path",           options[:options]
      assert_named_route "#{full_prefix}.xml",    "formatted_#{controller_name}_path", options[:options].merge(:format => 'xml')
      assert_named_route "#{full_prefix}/new",    "new_#{singular_name}_path",         options[:options]
      assert_named_route "#{full_prefix}/1",      "#{singular_name}_path",             options[:options].merge(:id => '1')
      assert_named_route "#{full_prefix}/1;edit", "edit_#{singular_name}_path",        options[:options].merge(:id => '1')
      assert_named_route "#{full_prefix}/1.xml",  "formatted_#{singular_name}_path",   options[:options].merge(:format => 'xml', :id => '1')
      yield options[:options] if block_given?
    end

    def assert_named_route(expected, route, options)
      actual =  @controller.send(route, options) rescue $!.class.name
      assert_equal expected, actual, "Error on route: #{route}(#{options.inspect})"
    end

    def assert_resource_methods(expected, resource, action_method, method)
      assert_equal expected.length, resource.send("#{action_method}_methods")[method].size, "#{resource.send("#{action_method}_methods")[method].inspect}"
      expected.each do |action|
        assert resource.send("#{action_method}_methods")[method].include?(action),
          "#{method} not in #{action_method} methods: #{resource.send("#{action_method}_methods")[method].inspect}"
      end
    end

    def distinct_routes? (r1, r2)
      if r1.conditions == r2.conditions and r1.requirements == r2.requirements then
        if r1.segments.collect(&:to_s) == r2.segments.collect(&:to_s) then
          return false
        end
      end
      true
    end

end
