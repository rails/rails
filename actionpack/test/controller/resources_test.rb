require File.dirname(__FILE__) + '/../abstract_unit'

class MessagesController < ActionController::Base
  def rescue_action(e) raise e end
end

class CommentsController < ActionController::Base
  def rescue_action(e) raise e end
end

class ResourcesTest < Test::Unit::TestCase
  def test_default_restful_routes
    with_restful_routing :messages do
      assert_restful_routes_for :messages do
        routing_options = {:controller => '/messages'}
      end
    end
  end

  def test_with_path_prefix
    with_restful_routing :messages, :path_prefix => '/thread/:thread_id' do
      assert_restful_routes_for :messages, :path_prefix => 'thread/5/', :options => { :thread_id => '5' }
    end
  end

  def test_with_collection_action
    with_restful_routing :messages, :collection => { :rss => :get } do
      assert_restful_routes_for :messages do |options|
        assert_routing "/messages;rss", options.merge(:action => 'rss')
      end
    end
  end

  def test_with_member_action
    [:put, :post].each do |method|
      with_restful_routing :messages, :member => { :mark => method } do
        assert_restful_routes_for :messages do |options|
          assert_recognizes(
            options.merge(:action => 'mark', :id => '1'), 
            {:path => "/messages/1;mark", :method => method})
        end
      end
    end
  end

  def test_with_new_action
    with_restful_routing :messages, :new => { :preview => :post } do
      assert_restful_routes_for :messages do |options|
        assert_recognizes(
          options.merge(:action => 'preview'), 
          {:path => "/messages/new;preview", :method => :post})
      end
    end
  end

  def xtest_nested_restful_routes
    with_routing do |set|
      set.draw do |map| 
        map.resources(:messages) do
          map.resources(:comments)
        end
      end

      with_options({ :controller => :comments }) do |controller|
        controller.assert_routing "/messages/1/comments",        :action => 'index'
        controller.assert_routing "/messages/1/comments.xml" ,   :action => 'index', :format => 'xml'
        controller.assert_routing "/messages/1/comments/new",    :action => 'new'
        controller.assert_routing "/messages/1/comments/1",      :action => 'show', :id => '1'
        controller.assert_routing "/messages/1/comments/1;edit", :action => 'edit', :id => '1'
        controller.assert_routing "/messages/1/comments/1.xml",  :action => 'show', :id => '1', :format => 'xml'
      end
    end
  end

  protected
    def with_restful_routing(resource, *args)
      with_routing do |set|
        set.draw { |map| map.resources(resource, *args) }
        yield
      end
    end
    
    def assert_restful_routes_for(controller_name, options = {})
      (options[:options] ||= {})[:controller] = controller_name.to_s

      with_options(options[:options]) do |controller|
        controller.assert_routing "/#{options[:path_prefix]}#{controller_name}",        :action => 'index'
        controller.assert_routing "/#{options[:path_prefix]}#{controller_name}.xml" ,   :action => 'index', :format => 'xml'
        controller.assert_routing "/#{options[:path_prefix]}#{controller_name}/new",    :action => 'new'
        controller.assert_routing "/#{options[:path_prefix]}#{controller_name}/1",      :action => 'show', :id => '1'
        controller.assert_routing "/#{options[:path_prefix]}#{controller_name}/1;edit", :action => 'edit', :id => '1'
        controller.assert_routing "/#{options[:path_prefix]}#{controller_name}/1.xml",  :action => 'show', :id => '1', :format => 'xml'
      end

      assert_recognizes(
        options[:options].merge(:action => 'create'),
        {:path => "/#{options[:path_prefix]}#{controller_name}", :method => :post})

      assert_recognizes(
        options[:options].merge(:action => 'update', :id => '1'),
        {:path => "/#{options[:path_prefix]}#{controller_name}/1", :method => :put})

      assert_recognizes(
        options[:options].merge(:action => 'destroy', :id => '1'),
        {:path => "/#{options[:path_prefix]}#{controller_name}/1", :method => :delete})
      
      yield options[:options] if block_given?
    end
end
