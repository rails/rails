require 'active_record_unit'
require 'fixtures/project'

class Task < ActiveRecord::Base
  set_table_name 'projects'
end

class Step < ActiveRecord::Base
  set_table_name 'projects'
end

class Bid < ActiveRecord::Base
  set_table_name 'projects'
end

class Tax < ActiveRecord::Base
  set_table_name 'projects'
end

class Fax < ActiveRecord::Base
  set_table_name 'projects'
end

class Series < ActiveRecord::Base
  set_table_name 'projects'
end

class PolymorphicRoutesTest < ActionController::TestCase
  include ActionController::UrlWriter
  self.default_url_options[:host] = 'example.com'

  def setup
    @project = Project.new
    @task = Task.new
    @step = Step.new
    @bid = Bid.new
    @tax = Tax.new
    @fax = Fax.new
    @series = Series.new
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

  def test_formatted_url_helper_is_deprecated
    with_test_routes do
      assert_deprecated do
        formatted_polymorphic_url([@project, :pdf])
      end
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
    end
  end

  def with_test_routes(options = {})
    with_routing do |set|
      set.draw do |map|
        map.resources :projects do |projects|
          projects.resources :tasks
          projects.resource :bid do |bid|
            bid.resources :tasks
          end
        end
        map.resources :taxes do |taxes|
          taxes.resources :faxes
          taxes.resource :bid
        end
        map.resources :series
      end

      ActionController::Routing::Routes.install_helpers(self.class)
      yield
    end
  end
  
  def with_admin_test_routes(options = {})
    with_routing do |set|
      set.draw do |map|
        map.namespace :admin do |admin|
          admin.resources :projects do |projects|
            projects.resources :tasks
            projects.resource :bid do |bid|
              bid.resources :tasks
            end
          end
          admin.resources :taxes do |taxes|
            taxes.resources :faxes
          end
          admin.resources :series
        end
      end

      ActionController::Routing::Routes.install_helpers(self.class)
      yield
    end
  end
  
  def with_admin_and_site_test_routes(options = {})
    with_routing do |set|
      set.draw do |map|
        map.namespace :admin do |admin|
          admin.resources :projects do |projects|
            projects.namespace :site do |site|
              site.resources :tasks do |tasks|
                tasks.resources :steps
              end
            end
          end
        end
      end

      ActionController::Routing::Routes.install_helpers(self.class)
      yield
    end
  end

end
