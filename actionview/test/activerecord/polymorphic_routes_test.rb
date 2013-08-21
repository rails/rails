require 'active_record_unit'
require 'fixtures/project'

class Task < ActiveRecord::Base
  self.table_name = 'projects'
end

class Step < ActiveRecord::Base
  self.table_name = 'projects'
end

class Bid < ActiveRecord::Base
  self.table_name = 'projects'
end

class Tax < ActiveRecord::Base
  self.table_name = 'projects'
end

class Fax < ActiveRecord::Base
  self.table_name = 'projects'
end

class Series < ActiveRecord::Base
  self.table_name = 'projects'
end

class ModelDelegator < ActiveRecord::Base
  self.table_name = 'projects'

  def to_model
    ModelDelegate.new
  end
end

class ModelDelegate
  def self.model_name
    ActiveModel::Name.new(self)
  end

  def to_param
    'overridden'
  end
end

module Blog
  class Post < ActiveRecord::Base
    self.table_name = 'projects'
  end

  class Blog < ActiveRecord::Base
    self.table_name = 'projects'
  end

  def self.use_relative_model_naming?
    true
  end
end

class PolymorphicRoutesTest < ActionController::TestCase
  include SharedTestRoutes.url_helpers
  self.default_url_options[:host] = 'example.com'

  def setup
    @project = Project.new
    @task = Task.new
    @step = Step.new
    @bid = Bid.new
    @tax = Tax.new
    @fax = Fax.new
    @delegator = ModelDelegator.new
    @series = Series.new
    @blog_post = Blog::Post.new
    @blog_blog = Blog::Blog.new
  end

  def test_passing_routes_proxy
    with_namespaced_routes(:blog) do
      proxy = ActionDispatch::Routing::RoutesProxy.new(_routes, self)
      @blog_post.save
      assert_equal "http://example.com/posts/#{@blog_post.id}", polymorphic_url([proxy, @blog_post])
    end
  end

  def test_namespaced_model
    with_namespaced_routes(:blog) do
      @blog_post.save
      assert_equal "http://example.com/posts/#{@blog_post.id}", polymorphic_url(@blog_post)
    end
  end

  def test_namespaced_model_with_name_the_same_as_namespace
    with_namespaced_routes(:blog) do
      @blog_blog.save
      assert_equal "http://example.com/blogs/#{@blog_blog.id}", polymorphic_url(@blog_blog)
    end
  end

  def test_namespaced_model_with_nested_resources
    with_namespaced_routes(:blog) do
      @blog_post.save
      @blog_blog.save
      assert_equal "http://example.com/blogs/#{@blog_blog.id}/posts/#{@blog_post.id}", polymorphic_url([@blog_blog, @blog_post])
    end
  end

  def test_with_nil
    with_test_routes do
      assert_raise ArgumentError, "Nil location provided. Can't build URI." do
        polymorphic_url(nil)
      end
    end
  end

  def test_with_record
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}", polymorphic_url(@project)
    end
  end

  def test_with_class
    with_test_routes do
      assert_equal "http://example.com/projects", polymorphic_url(@project.class)
    end
  end

  def test_with_new_record
    with_test_routes do
      assert_equal "http://example.com/projects", polymorphic_url(@project)
    end
  end

  def test_with_destroyed_record
    with_test_routes do
      @project.destroy
      assert_equal "http://example.com/projects", polymorphic_url(@project)
    end
  end

  def test_with_record_and_action
    with_test_routes do
      assert_equal "http://example.com/projects/new", polymorphic_url(@project, :action => 'new')
    end
  end

  def test_url_helper_prefixed_with_new
    with_test_routes do
      assert_equal "http://example.com/projects/new", new_polymorphic_url(@project)
    end
  end

  def test_url_helper_prefixed_with_edit
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}/edit", edit_polymorphic_url(@project)
    end
  end

  def test_url_helper_prefixed_with_edit_with_url_options
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}/edit?param1=10", edit_polymorphic_url(@project, :param1 => '10')
    end
  end

  def test_url_helper_with_url_options
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}?param1=10", polymorphic_url(@project, :param1 => '10')
    end
  end

  def test_format_option
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}.pdf", polymorphic_url(@project, :format => :pdf)
    end
  end

  def test_format_option_with_url_options
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}.pdf?param1=10", polymorphic_url(@project, :format => :pdf, :param1 => '10')
    end
  end

  def test_id_and_format_option
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}.pdf", polymorphic_url(:id => @project, :format => :pdf)
    end
  end

  def test_with_nested
    with_test_routes do
      @project.save
      @task.save
      assert_equal "http://example.com/projects/#{@project.id}/tasks/#{@task.id}", polymorphic_url([@project, @task])
    end
  end

  def test_with_nested_unsaved
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}/tasks", polymorphic_url([@project, @task])
    end
  end

  def test_with_nested_destroyed
    with_test_routes do
      @project.save
      @task.destroy
      assert_equal "http://example.com/projects/#{@project.id}/tasks", polymorphic_url([@project, @task])
    end
  end

  def test_with_nested_class
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}/tasks", polymorphic_url([@project, @task.class])
    end
  end

  def test_class_with_array_and_namespace
    with_admin_test_routes do
      assert_equal "http://example.com/admin/projects", polymorphic_url([:admin, @project.class])
    end
  end

  def test_new_with_array_and_namespace
    with_admin_test_routes do
      assert_equal "http://example.com/admin/projects/new", polymorphic_url([:admin, @project], :action => 'new')
    end
  end

  def test_unsaved_with_array_and_namespace
    with_admin_test_routes do
      assert_equal "http://example.com/admin/projects", polymorphic_url([:admin, @project])
    end
  end

  def test_nested_unsaved_with_array_and_namespace
    with_admin_test_routes do
      @project.save
      assert_equal "http://example.com/admin/projects/#{@project.id}/tasks", polymorphic_url([:admin, @project, @task])
    end
  end

  def test_nested_with_array_and_namespace
    with_admin_test_routes do
      @project.save
      @task.save
      assert_equal "http://example.com/admin/projects/#{@project.id}/tasks/#{@task.id}", polymorphic_url([:admin, @project, @task])
    end
  end

  def test_ordering_of_nesting_and_namespace
    with_admin_and_site_test_routes do
      @project.save
      @task.save
      @step.save
      assert_equal "http://example.com/admin/projects/#{@project.id}/site/tasks/#{@task.id}/steps/#{@step.id}", polymorphic_url([:admin, @project, :site, @task, @step])
    end
  end

  def test_nesting_with_array_ending_in_singleton_resource
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}/bid", polymorphic_url([@project, :bid])
    end
  end

  def test_nesting_with_array_containing_singleton_resource
    with_test_routes do
      @project.save
      @task.save
      assert_equal "http://example.com/projects/#{@project.id}/bid/tasks/#{@task.id}", polymorphic_url([@project, :bid, @task])
    end
  end

  def test_nesting_with_array_containing_singleton_resource_and_format
    with_test_routes do
      @project.save
      @task.save
      assert_equal "http://example.com/projects/#{@project.id}/bid/tasks/#{@task.id}.pdf", polymorphic_url([@project, :bid, @task], :format => :pdf)
    end
  end

  def test_nesting_with_array_containing_namespace_and_singleton_resource
    with_admin_test_routes do
      @project.save
      @task.save
      assert_equal "http://example.com/admin/projects/#{@project.id}/bid/tasks/#{@task.id}", polymorphic_url([:admin, @project, :bid, @task])
    end
  end

  def test_nesting_with_array_containing_nil
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}/bid", polymorphic_url([@project, nil, :bid])
    end
  end

  def test_with_array_containing_single_object
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}", polymorphic_url([nil, @project])
    end
  end

  def test_with_array_containing_single_name
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects", polymorphic_url([:projects])
    end
  end

  def test_with_array_containing_symbols
    with_test_routes do
      assert_equal "http://example.com/series/new", polymorphic_url([:new, :series])
    end
  end

  def test_with_hash
    with_test_routes do
      @project.save
      assert_equal "http://example.com/projects/#{@project.id}", polymorphic_url(:id => @project)
    end
  end

  def test_polymorphic_path_accepts_options
    with_test_routes do
      assert_equal "/projects/new", polymorphic_path(@project, :action => 'new')
    end
  end

  def test_polymorphic_path_does_not_modify_arguments
    with_admin_test_routes do
      @project.save
      @task.save

      options = {}
      object_array = [:admin, @project, @task]
      original_args = [object_array.dup, options.dup]

      assert_no_difference('object_array.size') { polymorphic_path(object_array, options) }
      assert_equal original_args, [object_array, options]
    end
  end

  # Tests for names where .plural.singular doesn't round-trip
  def test_with_irregular_plural_record
    with_test_routes do
      @tax.save
      assert_equal "http://example.com/taxes/#{@tax.id}", polymorphic_url(@tax)
    end
  end

  def test_with_irregular_plural_class
    with_test_routes do
      assert_equal "http://example.com/taxes", polymorphic_url(@tax.class)
    end
  end

  def test_with_irregular_plural_new_record
    with_test_routes do
      assert_equal "http://example.com/taxes", polymorphic_url(@tax)
    end
  end

  def test_with_irregular_plural_destroyed_record
    with_test_routes do
      @tax.destroy
      assert_equal "http://example.com/taxes", polymorphic_url(@tax)
    end
  end

  def test_with_irregular_plural_record_and_action
    with_test_routes do
      assert_equal "http://example.com/taxes/new", polymorphic_url(@tax, :action => 'new')
    end
  end

  def test_irregular_plural_url_helper_prefixed_with_new
    with_test_routes do
      assert_equal "http://example.com/taxes/new", new_polymorphic_url(@tax)
    end
  end

  def test_irregular_plural_url_helper_prefixed_with_edit
    with_test_routes do
      @tax.save
      assert_equal "http://example.com/taxes/#{@tax.id}/edit", edit_polymorphic_url(@tax)
    end
  end

  def test_with_nested_irregular_plurals
    with_test_routes do
      @tax.save
      @fax.save
      assert_equal "http://example.com/taxes/#{@tax.id}/faxes/#{@fax.id}", polymorphic_url([@tax, @fax])
    end
  end

  def test_with_nested_unsaved_irregular_plurals
    with_test_routes do
      @tax.save
      assert_equal "http://example.com/taxes/#{@tax.id}/faxes", polymorphic_url([@tax, @fax])
    end
  end

  def test_new_with_irregular_plural_array_and_namespace
    with_admin_test_routes do
      assert_equal "http://example.com/admin/taxes/new", polymorphic_url([:admin, @tax], :action => 'new')
    end
  end

  def test_class_with_irregular_plural_array_and_namespace
    with_admin_test_routes do
      assert_equal "http://example.com/admin/taxes", polymorphic_url([:admin, @tax.class])
    end
  end

  def test_unsaved_with_irregular_plural_array_and_namespace
    with_admin_test_routes do
      assert_equal "http://example.com/admin/taxes", polymorphic_url([:admin, @tax])
    end
  end

  def test_nesting_with_irregular_plurals_and_array_ending_in_singleton_resource
    with_test_routes do
      @tax.save
      assert_equal "http://example.com/taxes/#{@tax.id}/bid", polymorphic_url([@tax, :bid])
    end
  end

  def test_with_array_containing_single_irregular_plural_object
    with_test_routes do
      @tax.save
      assert_equal "http://example.com/taxes/#{@tax.id}", polymorphic_url([nil, @tax])
    end
  end

  def test_with_array_containing_single_name_irregular_plural
    with_test_routes do
      @tax.save
      assert_equal "http://example.com/taxes", polymorphic_url([:taxes])
    end
  end

 # Tests for uncountable names
  def test_uncountable_resource
    with_test_routes do
      @series.save
      assert_equal "http://example.com/series/#{@series.id}", polymorphic_url(@series)
      assert_equal "http://example.com/series", polymorphic_url(Series.new)
    end
  end

  def test_routing_a_to_model_delegate
    with_test_routes do
      @delegator.save
      assert_equal "http://example.com/model_delegates/overridden", polymorphic_url(@delegator)
    end
  end

  def with_namespaced_routes(name)
    with_routing do |set|
      set.draw do
        scope(:module => name) do
          resources :blogs do
            resources :posts
          end
          resources :posts
        end
      end

      self.class.send(:include, @routes.url_helpers)
      yield
    end
  end

  def with_test_routes(options = {})
    with_routing do |set|
      set.draw do
        resources :projects do
          resources :tasks
          resource :bid do
            resources :tasks
          end
        end
        resources :taxes do
          resources :faxes
          resource :bid
        end
        resources :series
        resources :model_delegates
      end

      self.class.send(:include, @routes.url_helpers)
      yield
    end
  end

  def with_admin_test_routes(options = {})
    with_routing do |set|
      set.draw do
        namespace :admin do
          resources :projects do
            resources :tasks
            resource :bid do
              resources :tasks
            end
          end
          resources :taxes do
            resources :faxes
          end
          resources :series
        end
      end

      self.class.send(:include, @routes.url_helpers)
      yield
    end
  end

  def with_admin_and_site_test_routes(options = {})
    with_routing do |set|
      set.draw do
        namespace :admin do
          resources :projects do
            namespace :site do
              resources :tasks do
                resources :steps
              end
            end
          end
        end
      end

      self.class.send(:include, @routes.url_helpers)
      yield
    end
  end
end
