require 'abstract_unit'
require "fixtures/project"

class Milestone < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
end

class ProjectManager < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  belongs_to :project
end

class Project < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  has_one :project_manager
  has_many :milestones
end


@project          = { :id => 1, :name => "Rails"}
@other_project    = { :id => 2, :name => "Ruby"}
@project_manager  = {:id => 5, :name => "David", :project_id =>1}
@other_project_manager  = {:id => 6, :name => "John", :project_id => nil}
@project_managers = [@project_manager]

ActiveResource::HttpMock.respond_to do |mock|
  mock.get    "/projects/.xml", {}, @project.to_xml(:root => 'project')
  mock.get    "/projects/1.xml", {}, @project.to_xml(:root => 'project')
  mock.get    "/projects/2.xml", {}, @other_project.to_xml(:root => 'project')
  mock.get    "/project_managers/5.xml", {}, @project_manager.to_xml(:root => 'project_manager')
  mock.get    "/project_managers/6.xml", {}, @other_project_manager.to_xml(:root => 'project_manager')
  mock.get    "/project_managers.xml?project_id=1", {}, @project_managers.to_xml
  mock.get    "/project_managers.xml?project_id=2", {}, [].to_xml
  mock.put    "/project_managers/6.xml", {}, nil, 204
end

class AssociationsTest < Test::Unit::TestCase

  def setup
    @project         = Project.find(1)
    @other_project   = Project.find(2)
    @project_manager = ProjectManager.find(5)
    @other_project_manager = ProjectManager.find(6)
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
end

