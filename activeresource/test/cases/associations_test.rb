require 'abstract_unit'
require "fixtures/project"

class ProjectManager < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  belongs_to :project
end

class Project < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  has_one :project_manager
  has_many :milestones
end

class Milestone < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
end

@project          = { :id => 1, :name => "Rails"}
@other_project    = { :id => 2, :name => "Ruby"}
@project_manager  = {:id => 5, :name => "David", :project_id =>1}
@other_project_manager  = {:id => 6, :name => "John", :project_id => nil}
@project_managers = [@project_manager]
@milestone        = { :id => 1, :title => "pre", :project_id => nil}
@other_milestone  = { :id => 2, :title => "rc", :project_id => nil}

ActiveResource::HttpMock.respond_to do |mock|
  mock.get    "/projects/.xml", {}, @project.to_xml(:root => 'project')
  mock.get    "/projects/1.xml", {}, @project.to_xml(:root => 'project')
  mock.get    "/projects/2.xml", {}, @other_project.to_xml(:root => 'project')
  mock.get    "/project_managers/5.xml", {}, @project_manager.to_xml(:root => 'project_manager')
  mock.get    "/project_managers/6.xml", {}, @other_project_manager.to_xml(:root => 'project_manager')
  mock.get    "/project_managers.xml?project_id=1", {}, @project_managers.to_xml
  mock.get    "/project_managers.xml?project_id=2", {}, [].to_xml
  mock.get    "/milestones.xml", {}, [@milestone].to_xml
  mock.get    "/milestones.xml?project_id=2", {}, [].to_xml
  mock.get    "/milestones.xml?project_id=1", {}, [@milestone].to_xml
  mock.put    "/project_managers/6.xml", {}, nil, 204
  mock.put    "/milestones/2.xml", {}, nil, 204
  mock.put    "/milestones/1.xml", {}, nil, 204
  mock.get    "/milestones/1.xml", {}, @milestone.to_xml(:root => 'milestone')
  mock.get    "/milestones/2.xml", {}, @other_milestone.to_xml(:root => 'milestone')
end

class AssociationsTest < Test::Unit::TestCase

  def setup
    @project         = Project.find(1)
    @other_project   = Project.find(2)
    @project_manager = ProjectManager.find(5)
    @other_project_manager = ProjectManager.find(6)
    @milestone       = Milestone.find(1)
    @other_milestone = Milestone.find(2)
  end

  #----------------------------------------------------------------------
  # has_one association
  #----------------------------------------------------------------------

  def test_has_one_should_add_a_resource_accessor
    assert @project.respond_to? :project_manager
  end

  def test_has_one_accessor_should_return_the_associated_project_manager
    assert_equal @project_manager, @project.project_manager
  end

  def test_has_one_accessor_should_return_nil_when_the_does_not_has_an_associated_resource
    assert_nil @other_project.project_manager
  end

  def test_has_one_should_assign_a_new_project_manager_when_it_does_not_has_a_project_manager
    @other_project.project_manager = @other_project_manager
    assert_equal @other_project.id, @other_project_manager.project_id
  end

  #----------------------------------------------------------------------
  # belogns_to association
  #----------------------------------------------------------------------

  def test_belongs_to_should_add_a_resource_accessor
    assert @project_manager.respond_to? :project
  end

  def test_belongs_to_accessor_should_return_the_associated_project
    assert_equal @project, @project_manager.project
  end

  def test_belongs_to_accessor_should_return_nil_when_the_does_not_has_an_associated_resource
    assert_nil @other_project_manager.project
  end

  def test_has_one_should_assign_a_new_project_manager_when_it_does_not_has_a_project_manager
    @other_project_manager.project = @other_project
    assert_equal @other_project_manager.project_id, @other_project.id
  end

  #----------------------------------------------------------------------
  # has_many association
  #----------------------------------------------------------------------

  def test_has_many_should_add_a_resource_accessor
    assert @project.respond_to? :milestones
  end

  def test_has_many_accessor_should_return_the_an_array_with_the_associated_milestones
    assert_equal [@milestone], @project.milestones
  end

  def test_has_many_accessor_should_return_the_an_empty_array_when_it_does_not_has_milestones
    assert_equal [], @other_project.milestones
  end

  def test_has_many_accessor_should_return_the_an_array_including_the_added_obj
    @project.milestones << @other_milestone
    assert_equal @other_milestone.project_id, @project.id
  end

  def test_has_many_accessor_should_return_the_an_array_without_including_the_deleted_obj
    @project.milestones << @other_milestone
    @project.milestones.delete(@other_milestone)
    assert_nil @other_milestone.project_id
  end

  def test_has_many_accessor_should_return_the_an_empty_array_after_clear
    @project.milestones << @other_milestone
    @project.milestones.clear

    assert_equal [], @project.milestones
  end
end

