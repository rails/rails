require 'abstract_unit'

class ResourcesController < ActionController::Base
  def index() render :nothing => true end
  alias_method :show, :index
  def rescue_action(e) raise e end
end

class ThreadsController  < ResourcesController; end
class MessagesController < ResourcesController; end
class CommentsController < ResourcesController; end
class AuthorsController < ResourcesController; end
class LogosController < ResourcesController; end

class AccountsController <  ResourcesController; end
class AdminController   <  ResourcesController; end
class ProductsController < ResourcesController; end
class ImagesController < ResourcesController; end

module Backoffice
  class ProductsController < ResourcesController; end
  class TagsController < ResourcesController; end
  class ManufacturersController < ResourcesController; end
  class ImagesController < ResourcesController; end

  module Admin
    class ProductsController < ResourcesController; end
    class ImagesController < ResourcesController; end
  end
end

class ResourcesTest < ActionController::TestCase
  # The assertions in these tests are incompatible with the hash method
  # optimisation.  This could indicate user level problems
  def setup
    ActionController::Base.optimise_named_routes = false
  end

  def teardown
    ActionController::Base.optimise_named_routes = true
  end

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

  def test_should_resource_controller_name_equal_resource_name_by_default
    resource = ActionController::Resources::Resource.new(:messages, {})
    assert_equal 'messages', resource.controller
  end

  def test_should_resource_controller_name_equal_controller_option
    resource = ActionController::Resources::Resource.new(:messages, :controller => 'posts')
    assert_equal 'posts', resource.controller
  end

  def test_should_all_singleton_paths_be_the_same
    [ :path, :nesting_path_prefix, :member_path ].each do |method|
      resource = ActionController::Resources::SingletonResource.new(:messages, :path_prefix => 'admin')
      assert_equal 'admin/messages', resource.send(method)
    end
  end

  def test_default_restful_routes
    with_restful_routing :messages do
      assert_simply_restful_for :messages
    end
  end

  def test_override_paths_for_default_restful_actions
    resource = ActionController::Resources::Resource.new(:messages,
      :path_names => {:new => 'nuevo', :edit => 'editar'})
    assert_equal resource.new_path, "#{resource.path}/nuevo"
  end

  def test_multiple_default_restful_routes
    with_restful_routing :messages, :comments do
      assert_simply_restful_for :messages
      assert_simply_restful_for :comments
    end
  end

  def test_with_custom_conditions
    with_restful_routing :messages, :conditions => { :subdomain => 'app' } do
      assert_equal 'app', ActionController::Routing::Routes.named_routes.routes[:messages].conditions[:subdomain]
    end
  end

  def test_irregular_id_with_no_requirements_should_raise_error
    expected_options = {:controller => 'messages', :action => 'show', :id => '1.1.1'}

    with_restful_routing :messages do
      assert_raise(ActionController::RoutingError) do
        assert_recognizes(expected_options, :path => 'messages/1.1.1', :method => :get)
      end
    end
  end

  def test_irregular_id_with_requirements_should_pass
    expected_options = {:controller => 'messages', :action => 'show', :id => '1.1.1'}

    with_restful_routing(:messages, :requirements => {:id => /[0-9]\.[0-9]\.[0-9]/}) do
      assert_recognizes(expected_options, :path => 'messages/1.1.1', :method => :get)
    end
  end

  def test_with_path_prefix_requirements
    expected_options = {:controller => 'messages', :action => 'show', :thread_id => '1.1.1', :id => '1'}
    with_restful_routing :messages, :path_prefix => '/thread/:thread_id', :requirements => {:thread_id => /[0-9]\.[0-9]\.[0-9]/} do
      assert_recognizes(expected_options, :path => 'thread/1.1.1/messages/1', :method => :get)
    end
  end

  def test_irregular_id_requirements_should_get_passed_to_member_actions
    expected_options = {:controller => 'messages', :action => 'custom', :id => '1.1.1'}

    with_restful_routing(:messages, :member => {:custom => :get}, :requirements => {:id => /[0-9]\.[0-9]\.[0-9]/}) do
      assert_recognizes(expected_options, :path => 'messages/1.1.1/custom', :method => :get)
    end
  end

  def test_with_path_prefix
    with_restful_routing :messages, :path_prefix => '/thread/:thread_id' do
      assert_simply_restful_for :messages, :path_prefix => 'thread/5/', :options => { :thread_id => '5' }
    end
  end

  def test_multiple_with_path_prefix
    with_restful_routing :messages, :comments, :path_prefix => '/thread/:thread_id' do
      assert_simply_restful_for :messages, :path_prefix => 'thread/5/', :options => { :thread_id => '5' }
      assert_simply_restful_for :comments, :path_prefix => 'thread/5/', :options => { :thread_id => '5' }
    end
  end

  def test_with_name_prefix
    with_restful_routing :messages, :name_prefix => 'post_' do
      assert_simply_restful_for :messages, :name_prefix => 'post_'
    end
  end

  def test_with_collection_actions
    actions = { 'a' => :get, 'b' => :put, 'c' => :post, 'd' => :delete }

    with_restful_routing :messages, :collection => actions do
      assert_restful_routes_for :messages do |options|
        actions.each do |action, method|
          assert_recognizes(options.merge(:action => action), :path => "/messages/#{action}", :method => method)
        end
      end

      assert_restful_named_routes_for :messages do |options|
        actions.keys.each do |action|
          assert_named_route "/messages/#{action}", "#{action}_messages_path", :action => action
        end
      end
    end
  end

  def test_with_collection_actions_and_name_prefix
    actions = { 'a' => :get, 'b' => :put, 'c' => :post, 'd' => :delete }

    with_restful_routing :messages, :path_prefix => '/threads/:thread_id', :name_prefix => "thread_", :collection => actions do
      assert_restful_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        actions.each do |action, method|
          assert_recognizes(options.merge(:action => action), :path => "/threads/1/messages/#{action}", :method => method)
        end
      end

      assert_restful_named_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        actions.keys.each do |action|
          assert_named_route "/threads/1/messages/#{action}", "#{action}_thread_messages_path", :action => action
        end
      end
    end
  end

  def test_with_collection_actions_and_name_prefix_and_member_action_with_same_name
    actions = { 'a' => :get }

    with_restful_routing :messages, :path_prefix => '/threads/:thread_id', :name_prefix => "thread_", :collection => actions, :member => actions do
      assert_restful_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        actions.each do |action, method|
          assert_recognizes(options.merge(:action => action), :path => "/threads/1/messages/#{action}", :method => method)
        end
      end

      assert_restful_named_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        actions.keys.each do |action|
          assert_named_route "/threads/1/messages/#{action}", "#{action}_thread_messages_path", :action => action
        end
      end
    end
  end

  def test_with_collection_action_and_name_prefix_and_formatted
    actions = { 'a' => :get, 'b' => :put, 'c' => :post, 'd' => :delete }

    with_restful_routing :messages, :path_prefix => '/threads/:thread_id', :name_prefix => "thread_", :collection => actions do
      assert_restful_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        actions.each do |action, method|
          assert_recognizes(options.merge(:action => action, :format => 'xml'), :path => "/threads/1/messages/#{action}.xml", :method => method)
        end
      end

      assert_restful_named_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        actions.keys.each do |action|
          assert_named_route "/threads/1/messages/#{action}.xml", "#{action}_thread_messages_path", :action => action, :format => 'xml'
        end
      end
    end
  end

  def test_with_member_action
    [:put, :post].each do |method|
      with_restful_routing :messages, :member => { :mark => method } do
        mark_options = {:action => 'mark', :id => '1'}
        mark_path    = "/messages/1/mark"
        assert_restful_routes_for :messages do |options|
          assert_recognizes(options.merge(mark_options), :path => mark_path, :method => method)
        end

        assert_restful_named_routes_for :messages do |options|
          assert_named_route mark_path, :mark_message_path, mark_options
        end
      end
    end
  end

  def test_with_member_action_and_requirement
    expected_options = {:controller => 'messages', :action => 'mark', :id => '1.1.1'}
  
    with_restful_routing(:messages, :requirements => {:id => /[0-9]\.[0-9]\.[0-9]/}, :member => { :mark => :get }) do
      assert_recognizes(expected_options, :path => 'messages/1.1.1/mark', :method => :get)
    end
  end

  def test_member_when_override_paths_for_default_restful_actions_with
    [:put, :post].each do |method|
      with_restful_routing :messages, :member => { :mark => method }, :path_names => {:new => 'nuevo'} do
        mark_options = {:action => 'mark', :id => '1', :controller => "messages"}
        mark_path    = "/messages/1/mark"

        assert_restful_routes_for :messages, :path_names => {:new => 'nuevo'} do |options|
          assert_recognizes(options.merge(mark_options), :path => mark_path, :method => method)
        end

        assert_restful_named_routes_for :messages, :path_names => {:new => 'nuevo'} do |options|
          assert_named_route mark_path, :mark_message_path, mark_options
        end
      end
    end
  end

  def test_member_when_changed_default_restful_actions_and_path_names_not_specified
    default_path_names = ActionController::Base.resources_path_names
    ActionController::Base.resources_path_names = {:new => 'nuevo', :edit => 'editar'}

    with_restful_routing :messages do
      new_options = { :action => 'new', :controller => 'messages' }
      new_path = "/messages/nuevo"
      edit_options = { :action => 'edit', :id => '1', :controller => 'messages' }
      edit_path = "/messages/1/editar"

      assert_restful_routes_for :messages do |options|
        assert_recognizes(options.merge(new_options), :path => new_path, :method => :get)
      end

      assert_restful_routes_for :messages do |options|
        assert_recognizes(options.merge(edit_options), :path => edit_path, :method => :get)
      end
    end
  ensure
    ActionController::Base.resources_path_names = default_path_names
  end

  def test_with_two_member_actions_with_same_method
    [:put, :post].each do |method|
      with_restful_routing :messages, :member => { :mark => method, :unmark => method } do
        %w(mark unmark).each do |action|
          action_options = {:action => action, :id => '1'}
          action_path    = "/messages/1/#{action}"
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

  def test_array_as_collection_or_member_method_value
    with_restful_routing :messages, :collection => { :search => [:get, :post] }, :member => { :toggle => [:get, :post] } do
      assert_restful_routes_for :messages do |options|
        [:get, :post].each do |method|
          assert_recognizes(options.merge(:action => 'search'), :path => "/messages/search", :method => method)
        end
        [:get, :post].each do |method|
          assert_recognizes(options.merge(:action => 'toggle', :id => '1'), :path => '/messages/1/toggle', :method => method)
        end
      end
    end
  end

  def test_with_new_action
    with_restful_routing :messages, :new => { :preview => :post } do
      preview_options = {:action => 'preview'}
      preview_path    = "/messages/new/preview"
      assert_restful_routes_for :messages do |options|
        assert_recognizes(options.merge(preview_options), :path => preview_path, :method => :post)
      end

      assert_restful_named_routes_for :messages do |options|
        assert_named_route preview_path, :preview_new_message_path, preview_options
      end
    end
  end

  def test_with_new_action_with_name_prefix
    with_restful_routing :messages, :new => { :preview => :post }, :path_prefix => '/threads/:thread_id', :name_prefix => 'thread_' do
      preview_options = {:action => 'preview', :thread_id => '1'}
      preview_path    = "/threads/1/messages/new/preview"
      assert_restful_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        assert_recognizes(options.merge(preview_options), :path => preview_path, :method => :post)
      end

      assert_restful_named_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        assert_named_route preview_path, :preview_new_thread_message_path, preview_options
      end
    end
  end

  def test_with_formatted_new_action_with_name_prefix
    with_restful_routing :messages, :new => { :preview => :post }, :path_prefix => '/threads/:thread_id', :name_prefix => 'thread_' do
      preview_options = {:action => 'preview', :thread_id => '1', :format => 'xml'}
      preview_path    = "/threads/1/messages/new/preview.xml"
      assert_restful_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        assert_recognizes(options.merge(preview_options), :path => preview_path, :method => :post)
      end

      assert_restful_named_routes_for :messages, :path_prefix => 'threads/1/', :name_prefix => 'thread_', :options => { :thread_id => '1' } do |options|
        assert_named_route preview_path, :preview_new_thread_message_path, preview_options
      end
    end
  end

  def test_override_new_method
    with_restful_routing :messages do
      assert_restful_routes_for :messages do |options|
        assert_recognizes(options.merge(:action => "new"), :path => "/messages/new", :method => :get)
        assert_raise(ActionController::MethodNotAllowed) do
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
        :name_prefix => 'thread_',
        :path_prefix => 'threads/1/',
        :options => { :thread_id => '1' }
      assert_simply_restful_for :comments,
        :name_prefix => 'thread_message_',
        :path_prefix => 'threads/1/messages/2/',
        :options => { :thread_id => '1', :message_id => '2' }
    end
  end

  def test_nested_restful_routes_with_overwritten_defaults
    with_routing do |set|
      set.draw do |map|
        map.resources :threads do |map|
          map.resources :messages, :name_prefix => nil do |map|
            map.resources :comments, :name_prefix => nil
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

  def test_shallow_nested_restful_routes
    with_routing do |set|
      set.draw do |map|
        map.resources :threads, :shallow => true do |map|
          map.resources :messages do |map|
            map.resources :comments
          end
        end
      end

      assert_simply_restful_for :threads,
        :shallow => true
      assert_simply_restful_for :messages,
        :name_prefix => 'thread_',
        :path_prefix => 'threads/1/',
        :shallow => true,
        :options => { :thread_id => '1' }
      assert_simply_restful_for :comments,
        :name_prefix => 'message_',
        :path_prefix => 'messages/2/',
        :shallow => true,
        :options => { :message_id => '2' }
    end
  end

  def test_shallow_nested_restful_routes_with_namespaces
    with_routing do |set|
      set.draw do |map|
        map.namespace :backoffice do |map|
          map.namespace :admin do |map|
            map.resources :products, :shallow => true do |map|
              map.resources :images
            end
          end
        end
      end

      assert_simply_restful_for :products,
        :controller => 'backoffice/admin/products',
        :namespace => 'backoffice/admin/',
        :name_prefix => 'backoffice_admin_',
        :path_prefix => 'backoffice/admin/',
        :shallow => true
      assert_simply_restful_for :images,
        :controller => 'backoffice/admin/images',
        :namespace => 'backoffice/admin/',
        :name_prefix => 'backoffice_admin_product_',
        :path_prefix => 'backoffice/admin/products/1/',
        :shallow => true,
        :options => { :product_id => '1' }
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

  def test_should_create_singleton_resource_routes
    with_singleton_resources :account do
      assert_singleton_restful_for :account
    end
  end

  def test_should_create_multiple_singleton_resource_routes
    with_singleton_resources :account, :logo do
      assert_singleton_restful_for :account
      assert_singleton_restful_for :logo
    end
  end

  def test_should_create_nested_singleton_resource_routes
    with_routing do |set|
      set.draw do |map|
        map.resource :admin, :controller => 'admin' do |admin|
          admin.resource :account
        end
      end

      assert_singleton_restful_for :admin, :controller => 'admin'
      assert_singleton_restful_for :account, :name_prefix => "admin_", :path_prefix => 'admin/'
    end
  end

  def test_resource_has_many_should_become_nested_resources
    with_routing do |set|
      set.draw do |map|
        map.resources :messages, :has_many => [ :comments, :authors ]
      end

      assert_simply_restful_for :messages
      assert_simply_restful_for :comments, :name_prefix => "message_", :path_prefix => 'messages/1/', :options => { :message_id => '1' }
      assert_simply_restful_for :authors,  :name_prefix => "message_", :path_prefix => 'messages/1/', :options => { :message_id => '1' }
    end
  end

  def test_resources_has_many_hash_should_become_nested_resources
    with_routing do |set|
      set.draw do |map|
        map.resources :threads, :has_many => { :messages => [ :comments, { :authors => :threads } ] }
      end

      assert_simply_restful_for :threads
      assert_simply_restful_for :messages, :name_prefix => "thread_", :path_prefix => 'threads/1/', :options => { :thread_id => '1' }
      assert_simply_restful_for :comments, :name_prefix => "thread_message_", :path_prefix => 'threads/1/messages/1/', :options => { :thread_id => '1', :message_id => '1' }
      assert_simply_restful_for :authors,  :name_prefix => "thread_message_", :path_prefix => 'threads/1/messages/1/', :options => { :thread_id => '1', :message_id => '1' }
      assert_simply_restful_for :threads,  :name_prefix => "thread_message_author_", :path_prefix => 'threads/1/messages/1/authors/1/', :options => { :thread_id => '1', :message_id => '1', :author_id => '1' }
    end
  end

  def test_shallow_resource_has_many_should_become_shallow_nested_resources
    with_routing do |set|
      set.draw do |map|
        map.resources :messages, :has_many => [ :comments, :authors ], :shallow => true
      end

      assert_simply_restful_for :messages, :shallow => true
      assert_simply_restful_for :comments, :name_prefix => "message_", :path_prefix => 'messages/1/', :shallow => true, :options => { :message_id => '1' }
      assert_simply_restful_for :authors,  :name_prefix => "message_", :path_prefix => 'messages/1/', :shallow => true, :options => { :message_id => '1' }
    end
  end

  def test_resource_has_one_should_become_nested_resources
    with_routing do |set|
      set.draw do |map|
        map.resources :messages, :has_one => :logo
      end

      assert_simply_restful_for :messages
      assert_singleton_restful_for :logo, :name_prefix => 'message_', :path_prefix => 'messages/1/', :options => { :message_id => '1' }
    end
  end

  def test_shallow_resource_has_one_should_become_shallow_nested_resources
    with_routing do |set|
      set.draw do |map|
        map.resources :messages, :has_one => :logo, :shallow => true
      end

      assert_simply_restful_for :messages, :shallow => true
      assert_singleton_restful_for :logo, :name_prefix => 'message_', :path_prefix => 'messages/1/', :shallow => true, :options => { :message_id => '1' }
    end
  end

  def test_singleton_resource_with_member_action
    [:put, :post].each do |method|
      with_singleton_resources :account, :member => { :reset => method } do
        reset_options = {:action => 'reset'}
        reset_path    = "/account/reset"
        assert_singleton_routes_for :account do |options|
          assert_recognizes(options.merge(reset_options), :path => reset_path, :method => method)
        end

        assert_singleton_named_routes_for :account do |options|
          assert_named_route reset_path, :reset_account_path, reset_options
        end
      end
    end
  end

  def test_singleton_resource_with_two_member_actions_with_same_method
    [:put, :post].each do |method|
      with_singleton_resources :account, :member => { :reset => method, :disable => method } do
        %w(reset disable).each do |action|
          action_options = {:action => action}
          action_path    = "/account/#{action}"
          assert_singleton_routes_for :account do |options|
            assert_recognizes(options.merge(action_options), :path => action_path, :method => method)
          end

          assert_singleton_named_routes_for :account do |options|
            assert_named_route action_path, "#{action}_account_path".to_sym, action_options
          end
        end
      end
    end
  end

  def test_should_nest_resources_in_singleton_resource
    with_routing do |set|
      set.draw do |map|
        map.resource :account do |account|
          account.resources :messages
        end
      end

      assert_singleton_restful_for :account
      assert_simply_restful_for :messages, :name_prefix => "account_", :path_prefix => 'account/'
    end
  end

  def test_should_nest_resources_in_singleton_resource_with_path_prefix
    with_routing do |set|
      set.draw do |map|
        map.resource(:account, :path_prefix => ':site_id') do |account|
          account.resources :messages
        end
      end

      assert_singleton_restful_for :account, :path_prefix => '7/', :options => { :site_id => '7' }
      assert_simply_restful_for :messages, :name_prefix => "account_", :path_prefix => '7/account/', :options => { :site_id => '7' }
    end
  end

  def test_should_nest_singleton_resource_in_resources
    with_routing do |set|
      set.draw do |map|
        map.resources :threads do |thread|
          thread.resource :admin, :controller => 'admin'
        end
      end

      assert_simply_restful_for :threads
      assert_singleton_restful_for :admin, :controller => 'admin', :name_prefix => 'thread_', :path_prefix => 'threads/5/', :options => { :thread_id => '5' }
    end
  end

  def test_should_not_allow_delete_or_put_on_collection_path
    controller_name = :messages
    with_restful_routing controller_name do
      options = { :controller => controller_name.to_s }
      collection_path = "/#{controller_name}"

      assert_raise(ActionController::MethodNotAllowed) do
        assert_recognizes(options.merge(:action => 'update'), :path => collection_path, :method => :put)
      end

      assert_raise(ActionController::MethodNotAllowed) do
        assert_recognizes(options.merge(:action => 'destroy'), :path => collection_path, :method => :delete)
      end
    end
  end

  def test_should_not_allow_invalid_head_method_for_member_routes
    with_routing do |set|
      set.draw do |map|
        assert_raise(ArgumentError) do
          map.resources :messages, :member => {:something => :head}
        end
      end
    end
  end

  def test_should_not_allow_invalid_http_methods_for_member_routes
    with_routing do |set|
      set.draw do |map|
        assert_raise(ArgumentError) do
          map.resources :messages, :member => {:something => :invalid}
        end
      end
    end
  end

  def test_resource_action_separator
    with_routing do |set|
      set.draw do |map|
        map.resources :messages, :collection => {:search => :get}, :new => {:preview => :any}, :name_prefix => 'thread_', :path_prefix => '/threads/:thread_id'
        map.resource :account, :member => {:login => :get}, :new => {:preview => :any}, :name_prefix => 'admin_', :path_prefix => '/admin'
      end

      action_separator = ActionController::Base.resource_action_separator

      assert_simply_restful_for :messages, :name_prefix => 'thread_', :path_prefix => 'threads/1/', :options => { :thread_id => '1' }
      assert_named_route "/threads/1/messages#{action_separator}search", "search_thread_messages_path", {}
      assert_named_route "/threads/1/messages/new", "new_thread_message_path", {}
      assert_named_route "/threads/1/messages/new#{action_separator}preview", "preview_new_thread_message_path", {}
      assert_singleton_restful_for :account, :name_prefix => 'admin_', :path_prefix => 'admin/'
      assert_named_route "/admin/account#{action_separator}login", "login_admin_account_path", {}
      assert_named_route "/admin/account/new", "new_admin_account_path", {}
      assert_named_route "/admin/account/new#{action_separator}preview", "preview_new_admin_account_path", {}
    end
  end

  def test_new_style_named_routes_for_resource
    with_routing do |set|
      set.draw do |map|
        map.resources :messages, :collection => {:search => :get}, :new => {:preview => :any}, :name_prefix => 'thread_', :path_prefix => '/threads/:thread_id'
      end
      assert_simply_restful_for :messages, :name_prefix => 'thread_', :path_prefix => 'threads/1/', :options => { :thread_id => '1' }
      assert_named_route "/threads/1/messages/search", "search_thread_messages_path", {}
      assert_named_route "/threads/1/messages/new", "new_thread_message_path", {}
      assert_named_route "/threads/1/messages/new/preview", "preview_new_thread_message_path", {}
    end
  end

  def test_new_style_named_routes_for_singleton_resource
    with_routing do |set|
      set.draw do |map|
        map.resource :account, :member => {:login => :get}, :new => {:preview => :any}, :name_prefix => 'admin_', :path_prefix => '/admin'
      end
      assert_singleton_restful_for :account, :name_prefix => 'admin_', :path_prefix => 'admin/'
      assert_named_route "/admin/account/login", "login_admin_account_path", {}
      assert_named_route "/admin/account/new", "new_admin_account_path", {}
      assert_named_route "/admin/account/new/preview", "preview_new_admin_account_path", {}
    end
  end

  def test_resources_in_namespace
    with_routing do |set|
      set.draw do |map|
        map.namespace :backoffice do |backoffice|
          backoffice.resources :products
        end
      end

      assert_simply_restful_for :products, :controller => "backoffice/products", :name_prefix => 'backoffice_', :path_prefix => 'backoffice/'
    end
  end

  def test_resource_has_many_in_namespace
    with_routing do |set|
      set.draw do |map|
        map.namespace :backoffice do |backoffice|
          backoffice.resources :products, :has_many => :tags
        end
      end

      assert_simply_restful_for :products,  :controller => "backoffice/products", :name_prefix => 'backoffice_',          :path_prefix => 'backoffice/'
      assert_simply_restful_for :tags,      :controller => "backoffice/tags",     :name_prefix => "backoffice_product_",  :path_prefix => 'backoffice/products/1/', :options => { :product_id => '1' }
    end
  end

  def test_resource_has_one_in_namespace
    with_routing do |set|
      set.draw do |map|
        map.namespace :backoffice do |backoffice|
          backoffice.resources :products, :has_one => :manufacturer
        end
      end

      assert_simply_restful_for :products, :controller => "backoffice/products", :name_prefix => 'backoffice_', :path_prefix => 'backoffice/'
      assert_singleton_restful_for :manufacturer, :controller => "backoffice/manufacturers", :name_prefix => 'backoffice_product_', :path_prefix => 'backoffice/products/1/', :options => { :product_id => '1' }
    end
  end

  def test_resources_in_nested_namespace
    with_routing do |set|
      set.draw do |map|
        map.namespace :backoffice do |backoffice|
          backoffice.namespace :admin do |admin|
            admin.resources :products
          end
        end
      end

      assert_simply_restful_for :products, :controller => "backoffice/admin/products", :name_prefix => 'backoffice_admin_', :path_prefix => 'backoffice/admin/'
    end
  end

  def test_resources_using_namespace
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :namespace => "backoffice/"
      end

      assert_simply_restful_for :products, :controller => "backoffice/products"
    end
  end

  def test_nested_resources_using_namespace
    with_routing do |set|
      set.draw do |map|
        map.namespace :backoffice do |backoffice|
          backoffice.resources :products do |products|
            products.resources :images
          end
        end
      end

      assert_simply_restful_for :images, :controller => "backoffice/images", :name_prefix => 'backoffice_product_', :path_prefix => 'backoffice/products/1/', :options => {:product_id => '1'}
    end
  end

  def test_nested_resources_in_nested_namespace
    with_routing do |set|
      set.draw do |map|
        map.namespace :backoffice do |backoffice|
          backoffice.namespace :admin do |admin|
            admin.resources :products do |products|
              products.resources :images
            end
          end
        end
      end

      assert_simply_restful_for :images, :controller => "backoffice/admin/images", :name_prefix => 'backoffice_admin_product_', :path_prefix => 'backoffice/admin/products/1/', :options => {:product_id => '1'}
    end
  end

  def test_with_path_segment
    with_restful_routing :messages do
      assert_simply_restful_for :messages
      assert_recognizes({:controller => "messages", :action => "index"}, "/messages")
      assert_recognizes({:controller => "messages", :action => "index"}, "/messages/")
    end

     with_restful_routing :messages, :as => 'reviews' do
       assert_simply_restful_for :messages, :as => 'reviews'
      assert_recognizes({:controller => "messages", :action => "index"}, "/reviews")
      assert_recognizes({:controller => "messages", :action => "index"}, "/reviews/")
     end
  end

  def test_multiple_with_path_segment_and_controller
    with_routing do |set|
      set.draw do |map|
        map.resources :products do |products|
          products.resources :product_reviews, :as => 'reviews', :controller => 'messages'
        end
        map.resources :tutors do |tutors|
          tutors.resources :tutor_reviews, :as => 'reviews', :controller => 'comments'
        end
      end

      assert_simply_restful_for :product_reviews, :controller=>'messages', :as => 'reviews', :name_prefix => 'product_', :path_prefix => 'products/1/', :options => {:product_id => '1'}
      assert_simply_restful_for :tutor_reviews,:controller=>'comments', :as => 'reviews', :name_prefix => 'tutor_', :path_prefix => 'tutors/1/', :options => {:tutor_id => '1'}
    end
  end

  def test_with_path_segment_path_prefix_requirements
    expected_options = {:controller => 'messages', :action => 'show', :thread_id => '1.1.1', :id => '1'}
    with_restful_routing :messages, :as => 'comments',:path_prefix => '/thread/:thread_id', :requirements => { :thread_id => /[0-9]\.[0-9]\.[0-9]/ } do
      assert_recognizes(expected_options, :path => 'thread/1.1.1/comments/1', :method => :get)
    end
  end

  def test_resource_has_only_show_action
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :only => :show
      end

      assert_resource_allowed_routes('products', {},                    { :id => '1' }, :show, [:index, :new, :create, :edit, :update, :destroy])
      assert_resource_allowed_routes('products', { :format => 'xml' },  { :id => '1' }, :show, [:index, :new, :create, :edit, :update, :destroy])
    end
  end

  def test_singleton_resource_has_only_show_action
    with_routing do |set|
      set.draw do |map|
        map.resource :account, :only => :show
      end

      assert_singleton_resource_allowed_routes('accounts', {},                    :show, [:index, :new, :create, :edit, :update, :destroy])
      assert_singleton_resource_allowed_routes('accounts', { :format => 'xml' },  :show, [:index, :new, :create, :edit, :update, :destroy])
    end
  end

  def test_resource_does_not_have_destroy_action
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :except => :destroy
      end

      assert_resource_allowed_routes('products', {},                    { :id => '1' }, [:index, :new, :create, :show, :edit, :update], :destroy)
      assert_resource_allowed_routes('products', { :format => 'xml' },  { :id => '1' }, [:index, :new, :create, :show, :edit, :update], :destroy)
    end
  end

  def test_singleton_resource_does_not_have_destroy_action
    with_routing do |set|
      set.draw do |map|
        map.resource :account, :except => :destroy
      end

      assert_singleton_resource_allowed_routes('accounts', {},                    [:new, :create, :show, :edit, :update], :destroy)
      assert_singleton_resource_allowed_routes('accounts', { :format => 'xml' },  [:new, :create, :show, :edit, :update], :destroy)
    end
  end

  def test_resource_has_only_create_action_and_named_route
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :only => :create
      end

      assert_resource_allowed_routes('products', {},                    { :id => '1' }, :create, [:index, :new, :show, :edit, :update, :destroy])
      assert_resource_allowed_routes('products', { :format => 'xml' },  { :id => '1' }, :create, [:index, :new, :show, :edit, :update, :destroy])

      assert_not_nil set.named_routes[:products]
    end
  end

  def test_resource_has_only_update_action_and_named_route
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :only => :update
      end

      assert_resource_allowed_routes('products', {},                    { :id => '1' }, :update, [:index, :new, :create, :show, :edit, :destroy])
      assert_resource_allowed_routes('products', { :format => 'xml' },  { :id => '1' }, :update, [:index, :new, :create, :show, :edit, :destroy])

      assert_not_nil set.named_routes[:product]
    end
  end

  def test_resource_has_only_destroy_action_and_named_route
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :only => :destroy
      end

      assert_resource_allowed_routes('products', {},                    { :id => '1' }, :destroy, [:index, :new, :create, :show, :edit, :update])
      assert_resource_allowed_routes('products', { :format => 'xml' },  { :id => '1' }, :destroy, [:index, :new, :create, :show, :edit, :update])

      assert_not_nil set.named_routes[:product]
    end
  end

  def test_singleton_resource_has_only_create_action_and_named_route
    with_routing do |set|
      set.draw do |map|
        map.resource :account, :only => :create
      end

      assert_singleton_resource_allowed_routes('accounts', {},                    :create, [:new, :show, :edit, :update, :destroy])
      assert_singleton_resource_allowed_routes('accounts', { :format => 'xml' },  :create, [:new, :show, :edit, :update, :destroy])

      assert_not_nil set.named_routes[:account]
    end
  end

  def test_singleton_resource_has_only_update_action_and_named_route
    with_routing do |set|
      set.draw do |map|
        map.resource :account, :only => :update
      end

      assert_singleton_resource_allowed_routes('accounts', {},                    :update, [:new, :create, :show, :edit, :destroy])
      assert_singleton_resource_allowed_routes('accounts', { :format => 'xml' },  :update, [:new, :create, :show, :edit, :destroy])

      assert_not_nil set.named_routes[:account]
    end
  end

  def test_singleton_resource_has_only_destroy_action_and_named_route
    with_routing do |set|
      set.draw do |map|
        map.resource :account, :only => :destroy
      end

      assert_singleton_resource_allowed_routes('accounts', {},                    :destroy, [:new, :create, :show, :edit, :update])
      assert_singleton_resource_allowed_routes('accounts', { :format => 'xml' },  :destroy, [:new, :create, :show, :edit, :update])

      assert_not_nil set.named_routes[:account]
    end
  end

  def test_resource_has_only_collection_action
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :except => :all, :collection => { :sale => :get }
      end

      assert_resource_allowed_routes('products', {},                    { :id => '1' }, [], [:index, :new, :create, :show, :edit, :update, :destroy])
      assert_resource_allowed_routes('products', { :format => 'xml' },  { :id => '1' }, [], [:index, :new, :create, :show, :edit, :update, :destroy])

      assert_recognizes({ :controller => 'products', :action => 'sale' },                   :path => 'products/sale',     :method => :get)
      assert_recognizes({ :controller => 'products', :action => 'sale', :format => 'xml' }, :path => 'products/sale.xml', :method => :get)
    end
  end

  def test_resource_has_only_member_action
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :except => :all, :member => { :preview => :get }
      end

      assert_resource_allowed_routes('products', {},                    { :id => '1' }, [], [:index, :new, :create, :show, :edit, :update, :destroy])
      assert_resource_allowed_routes('products', { :format => 'xml' },  { :id => '1' }, [], [:index, :new, :create, :show, :edit, :update, :destroy])

      assert_recognizes({ :controller => 'products', :action => 'preview', :id => '1' },                    :path => 'products/1/preview',      :method => :get)
      assert_recognizes({ :controller => 'products', :action => 'preview', :id => '1', :format => 'xml' },  :path => 'products/1/preview.xml',  :method => :get)
    end
  end

  def test_singleton_resource_has_only_member_action
    with_routing do |set|
      set.draw do |map|
        map.resource :account, :except => :all, :member => { :signup => :get }
      end

      assert_singleton_resource_allowed_routes('accounts', {},                    [], [:new, :create, :show, :edit, :update, :destroy])
      assert_singleton_resource_allowed_routes('accounts', { :format => 'xml' },  [], [:new, :create, :show, :edit, :update, :destroy])

      assert_recognizes({ :controller => 'accounts', :action => 'signup' },                   :path => 'account/signup',      :method => :get)
      assert_recognizes({ :controller => 'accounts', :action => 'signup', :format => 'xml' }, :path => 'account/signup.xml',  :method => :get)
    end
  end

  def test_nested_resource_has_only_show_and_member_action
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :only => [:index, :show] do |product|
          product.resources :images, :member => { :thumbnail => :get }, :only => :show
        end
      end

      assert_resource_allowed_routes('images', { :product_id => '1' },                    { :id => '2' }, :show, [:index, :new, :create, :edit, :update, :destroy], 'products/1/images')
      assert_resource_allowed_routes('images', { :product_id => '1', :format => 'xml' },  { :id => '2' }, :show, [:index, :new, :create, :edit, :update, :destroy], 'products/1/images')

      assert_recognizes({ :controller => 'images', :action => 'thumbnail', :product_id => '1', :id => '2' },                    :path => 'products/1/images/2/thumbnail', :method => :get)
      assert_recognizes({ :controller => 'images', :action => 'thumbnail', :product_id => '1', :id => '2', :format => 'jpg' },  :path => 'products/1/images/2/thumbnail.jpg', :method => :get)
    end
  end

  def test_nested_resource_does_not_inherit_only_option
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :only => :show do |product|
          product.resources :images, :except => :destroy
        end
      end

      assert_resource_allowed_routes('images', { :product_id => '1' },                    { :id => '2' }, [:index, :new, :create, :show, :edit, :update], :destroy, 'products/1/images')
      assert_resource_allowed_routes('images', { :product_id => '1', :format => 'xml' },  { :id => '2' }, [:index, :new, :create, :show, :edit, :update], :destroy, 'products/1/images')
    end
  end

  def test_nested_resource_does_not_inherit_only_option_by_default
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :only => :show do |product|
          product.resources :images
        end
      end

      assert_resource_allowed_routes('images', { :product_id => '1' },                    { :id => '2' }, [:index, :new, :create, :show, :edit, :update, :destory], [], 'products/1/images')
      assert_resource_allowed_routes('images', { :product_id => '1', :format => 'xml' },  { :id => '2' }, [:index, :new, :create, :show, :edit, :update, :destroy], [], 'products/1/images')
    end
  end

  def test_nested_resource_does_not_inherit_except_option
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :except => :show do |product|
          product.resources :images, :only => :destroy
        end
      end

      assert_resource_allowed_routes('images', { :product_id => '1' },                    { :id => '2' }, :destroy, [:index, :new, :create, :show, :edit, :update], 'products/1/images')
      assert_resource_allowed_routes('images', { :product_id => '1', :format => 'xml' },  { :id => '2' }, :destroy, [:index, :new, :create, :show, :edit, :update], 'products/1/images')
    end
  end

  def test_nested_resource_does_not_inherit_except_option_by_default
    with_routing do |set|
      set.draw do |map|
        map.resources :products, :except => :show do |product|
          product.resources :images
        end
      end

      assert_resource_allowed_routes('images', { :product_id => '1' },                    { :id => '2' }, [:index, :new, :create, :show, :edit, :update, :destroy], [], 'products/1/images')
      assert_resource_allowed_routes('images', { :product_id => '1', :format => 'xml' },  { :id => '2' }, [:index, :new, :create, :show, :edit, :update, :destroy], [], 'products/1/images')
    end
  end

  def test_default_singleton_restful_route_uses_get
    with_routing do |set|
      set.draw do |map|
        map.resource :product
      end

      assert_equal :get, set.named_routes.routes[:product].conditions[:method]
    end
  end

  protected
    def with_restful_routing(*args)
      with_routing do |set|
        set.draw { |map| map.resources(*args) }
        yield
      end
    end

    def with_singleton_resources(*args)
      with_routing do |set|
        set.draw { |map| map.resource(*args) }
        yield
      end
    end

    # runs assert_restful_routes_for and assert_restful_named_routes for on the controller_name and options, without passing a block.
    def assert_simply_restful_for(controller_name, options = {})
      assert_restful_routes_for       controller_name, options
      assert_restful_named_routes_for controller_name, nil, options
    end

    def assert_singleton_restful_for(singleton_name, options = {})
      assert_singleton_routes_for       singleton_name, options
      assert_singleton_named_routes_for singleton_name, options
    end

    def assert_restful_routes_for(controller_name, options = {})
      options[:options] ||= {}
      options[:options][:controller] = options[:controller] || controller_name.to_s

      if options[:shallow]
        options[:shallow_options] ||= {}
        options[:shallow_options][:controller] = options[:options][:controller]
      else
        options[:shallow_options] = options[:options]
      end

      new_action    = ActionController::Base.resources_path_names[:new] || "new"
      edit_action   = ActionController::Base.resources_path_names[:edit] || "edit"
      if options[:path_names]
        new_action  = options[:path_names][:new] if options[:path_names][:new]
        edit_action = options[:path_names][:edit] if options[:path_names][:edit]
      end

      path                       = "#{options[:as] || controller_name}"
      collection_path            = "/#{options[:path_prefix]}#{path}"
      shallow_path               = "/#{options[:shallow] ? options[:namespace] : options[:path_prefix]}#{path}"
      member_path                = "#{shallow_path}/1"
      new_path                   = "#{collection_path}/#{new_action}"
      edit_member_path           = "#{member_path}/#{edit_action}"
      formatted_edit_member_path = "#{member_path}/#{edit_action}.xml"

      with_options(options[:options]) do |controller|
        controller.assert_routing collection_path,            :action => 'index'
        controller.assert_routing new_path,                   :action => 'new'
        controller.assert_routing "#{collection_path}.xml",   :action => 'index',            :format => 'xml'
        controller.assert_routing "#{new_path}.xml",          :action => 'new',              :format => 'xml'
      end

      with_options(options[:shallow_options]) do |controller|
        controller.assert_routing member_path,                :action => 'show', :id => '1'
        controller.assert_routing edit_member_path,           :action => 'edit', :id => '1'
        controller.assert_routing "#{member_path}.xml",       :action => 'show', :id => '1', :format => 'xml'
        controller.assert_routing formatted_edit_member_path, :action => 'edit', :id => '1', :format => 'xml'
      end

      assert_recognizes(options[:options].merge(:action => 'index'),               :path => collection_path,  :method => :get)
      assert_recognizes(options[:options].merge(:action => 'new'),                 :path => new_path,         :method => :get)
      assert_recognizes(options[:options].merge(:action => 'create'),              :path => collection_path,  :method => :post)
      assert_recognizes(options[:shallow_options].merge(:action => 'show',    :id => '1'), :path => member_path,      :method => :get)
      assert_recognizes(options[:shallow_options].merge(:action => 'edit',    :id => '1'), :path => edit_member_path, :method => :get)
      assert_recognizes(options[:shallow_options].merge(:action => 'update',  :id => '1'), :path => member_path,      :method => :put)
      assert_recognizes(options[:shallow_options].merge(:action => 'destroy', :id => '1'), :path => member_path,      :method => :delete)

      assert_recognizes(options[:options].merge(:action => 'index',  :format => 'xml'), :path => "#{collection_path}.xml",   :method => :get)
      assert_recognizes(options[:options].merge(:action => 'new',    :format => 'xml'), :path => "#{new_path}.xml",          :method => :get)
      assert_recognizes(options[:options].merge(:action => 'create', :format => 'xml'), :path => "#{collection_path}.xml",   :method => :post)
      assert_recognizes(options[:shallow_options].merge(:action => 'show',    :id => '1', :format => 'xml'), :path => "#{member_path}.xml",       :method => :get)
      assert_recognizes(options[:shallow_options].merge(:action => 'edit',    :id => '1', :format => 'xml'), :path => formatted_edit_member_path, :method => :get)
      assert_recognizes(options[:shallow_options].merge(:action => 'update',  :id => '1', :format => 'xml'), :path => "#{member_path}.xml",       :method => :put)
      assert_recognizes(options[:shallow_options].merge(:action => 'destroy', :id => '1', :format => 'xml'), :path => "#{member_path}.xml",       :method => :delete)

      yield options[:options] if block_given?
    end

    # test named routes like foo_path and foos_path map to the correct options.
    def assert_restful_named_routes_for(controller_name, singular_name = nil, options = {})
      if singular_name.is_a?(Hash)
        options       = singular_name
        singular_name = nil
      end
      singular_name ||= controller_name.to_s.singularize

      options[:options] ||= {}
      options[:options][:controller] = options[:controller] || controller_name.to_s

      if options[:shallow]
        options[:shallow_options] ||= {}
        options[:shallow_options][:controller] = options[:options][:controller]
      else
        options[:shallow_options] = options[:options]
      end

      @controller = "#{options[:options][:controller].camelize}Controller".constantize.new
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new
      get :index, options[:options]
      options[:options].delete :action

      path = "#{options[:as] || controller_name}"
      shallow_path = "/#{options[:shallow] ? options[:namespace] : options[:path_prefix]}#{path}"
      full_path = "/#{options[:path_prefix]}#{path}"
      name_prefix = options[:name_prefix]
      shallow_prefix = options[:shallow] ? options[:namespace].try(:gsub, /\//, '_') : options[:name_prefix]

      new_action  = "new"
      edit_action = "edit"
      if options[:path_names]
        new_action  = options[:path_names][:new]  || "new"
        edit_action = options[:path_names][:edit] || "edit"
      end

      assert_named_route "#{full_path}", "#{name_prefix}#{controller_name}_path", options[:options]
      assert_named_route "#{full_path}.xml", "#{name_prefix}#{controller_name}_path", options[:options].merge(:format => 'xml')
      assert_named_route "#{shallow_path}/1", "#{shallow_prefix}#{singular_name}_path", options[:shallow_options].merge(:id => '1')
      assert_named_route "#{shallow_path}/1.xml", "#{shallow_prefix}#{singular_name}_path", options[:shallow_options].merge(:id => '1', :format => 'xml')

      assert_named_route "#{full_path}/#{new_action}", "new_#{name_prefix}#{singular_name}_path", options[:options]
      assert_named_route "#{full_path}/#{new_action}.xml", "new_#{name_prefix}#{singular_name}_path", options[:options].merge(:format => 'xml')
      assert_named_route "#{shallow_path}/1/#{edit_action}", "edit_#{shallow_prefix}#{singular_name}_path", options[:shallow_options].merge(:id => '1')
      assert_named_route "#{shallow_path}/1/#{edit_action}.xml", "edit_#{shallow_prefix}#{singular_name}_path", options[:shallow_options].merge(:id => '1', :format => 'xml')

      yield options[:options] if block_given?
    end

    def assert_singleton_routes_for(singleton_name, options = {})
      options[:options] ||= {}
      options[:options][:controller] = options[:controller] || singleton_name.to_s.pluralize

      full_path           = "/#{options[:path_prefix]}#{options[:as] || singleton_name}"
      new_path            = "#{full_path}/new"
      edit_path           = "#{full_path}/edit"
      formatted_edit_path = "#{full_path}/edit.xml"

      with_options options[:options] do |controller|
        controller.assert_routing full_path,           :action => 'show'
        controller.assert_routing new_path,            :action => 'new'
        controller.assert_routing edit_path,           :action => 'edit'
        controller.assert_routing "#{full_path}.xml",  :action => 'show', :format => 'xml'
        controller.assert_routing "#{new_path}.xml",   :action => 'new',  :format => 'xml'
        controller.assert_routing formatted_edit_path, :action => 'edit', :format => 'xml'
      end

      assert_recognizes(options[:options].merge(:action => 'show'),    :path => full_path, :method => :get)
      assert_recognizes(options[:options].merge(:action => 'new'),     :path => new_path,  :method => :get)
      assert_recognizes(options[:options].merge(:action => 'edit'),    :path => edit_path, :method => :get)
      assert_recognizes(options[:options].merge(:action => 'create'),  :path => full_path, :method => :post)
      assert_recognizes(options[:options].merge(:action => 'update'),  :path => full_path, :method => :put)
      assert_recognizes(options[:options].merge(:action => 'destroy'), :path => full_path, :method => :delete)

      assert_recognizes(options[:options].merge(:action => 'show',    :format => 'xml'), :path => "#{full_path}.xml",  :method => :get)
      assert_recognizes(options[:options].merge(:action => 'new',     :format => 'xml'), :path => "#{new_path}.xml",   :method => :get)
      assert_recognizes(options[:options].merge(:action => 'edit',    :format => 'xml'), :path => formatted_edit_path, :method => :get)
      assert_recognizes(options[:options].merge(:action => 'create',  :format => 'xml'), :path => "#{full_path}.xml",  :method => :post)
      assert_recognizes(options[:options].merge(:action => 'update',  :format => 'xml'), :path => "#{full_path}.xml",  :method => :put)
      assert_recognizes(options[:options].merge(:action => 'destroy', :format => 'xml'), :path => "#{full_path}.xml",  :method => :delete)

      yield options[:options] if block_given?
    end

    def assert_singleton_named_routes_for(singleton_name, options = {})
      (options[:options] ||= {})[:controller] ||= singleton_name.to_s.pluralize
      @controller = "#{options[:options][:controller].camelize}Controller".constantize.new
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new
      get :show, options[:options]
      options[:options].delete :action

      full_path = "/#{options[:path_prefix]}#{options[:as] || singleton_name}"
      name_prefix = options[:name_prefix]

      assert_named_route "#{full_path}",          "#{name_prefix}#{singleton_name}_path",                options[:options]
      assert_named_route "#{full_path}.xml",      "#{name_prefix}#{singleton_name}_path",      options[:options].merge(:format => 'xml')

      assert_named_route "#{full_path}/new",      "new_#{name_prefix}#{singleton_name}_path",            options[:options]
      assert_named_route "#{full_path}/new.xml",  "new_#{name_prefix}#{singleton_name}_path",  options[:options].merge(:format => 'xml')
      assert_named_route "#{full_path}/edit",     "edit_#{name_prefix}#{singleton_name}_path",           options[:options]
      assert_named_route "#{full_path}/edit.xml", "edit_#{name_prefix}#{singleton_name}_path", options[:options].merge(:format => 'xml')
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

    def assert_resource_allowed_routes(controller, options, shallow_options, allowed, not_allowed, path = controller)
      shallow_path = "#{path}/#{shallow_options[:id]}"
      format = options[:format] && ".#{options[:format]}"
      options.merge!(:controller => controller)
      shallow_options.merge!(options)

      assert_whether_allowed(allowed, not_allowed, options,         'index',    "#{path}#{format}",               :get)
      assert_whether_allowed(allowed, not_allowed, options,         'new',      "#{path}/new#{format}",           :get)
      assert_whether_allowed(allowed, not_allowed, options,         'create',   "#{path}#{format}",               :post)
      assert_whether_allowed(allowed, not_allowed, shallow_options, 'show',     "#{shallow_path}#{format}",       :get)
      assert_whether_allowed(allowed, not_allowed, shallow_options, 'edit',     "#{shallow_path}/edit#{format}",  :get)
      assert_whether_allowed(allowed, not_allowed, shallow_options, 'update',   "#{shallow_path}#{format}",       :put)
      assert_whether_allowed(allowed, not_allowed, shallow_options, 'destroy',  "#{shallow_path}#{format}",       :delete)
    end

    def assert_singleton_resource_allowed_routes(controller, options, allowed, not_allowed, path = controller.singularize)
      format = options[:format] && ".#{options[:format]}"
      options.merge!(:controller => controller)

      assert_whether_allowed(allowed, not_allowed, options, 'new',      "#{path}/new#{format}",   :get)
      assert_whether_allowed(allowed, not_allowed, options, 'create',   "#{path}#{format}",       :post)
      assert_whether_allowed(allowed, not_allowed, options, 'show',     "#{path}#{format}",       :get)
      assert_whether_allowed(allowed, not_allowed, options, 'edit',     "#{path}/edit#{format}",  :get)
      assert_whether_allowed(allowed, not_allowed, options, 'update',   "#{path}#{format}",       :put)
      assert_whether_allowed(allowed, not_allowed, options, 'destroy',  "#{path}#{format}",       :delete)
    end

    def assert_whether_allowed(allowed, not_allowed, options, action, path, method)
      action = action.to_sym
      options = options.merge(:action => action.to_s)
      path_options = { :path => path, :method => method }

      if Array(allowed).include?(action)
        assert_recognizes options, path_options
      elsif Array(not_allowed).include?(action)
        assert_not_recognizes options, path_options
      end
    end

    def assert_not_recognizes(expected_options, path)
      assert_raise ActionController::RoutingError, ActionController::MethodNotAllowed, Assertion do
        assert_recognizes(expected_options, path)
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
