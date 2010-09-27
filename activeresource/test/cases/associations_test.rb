require 'abstract_unit'
require "fixtures/project"

class ProjectManager < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
end

class Project < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  has_one :project_manager
end

@project = { :id => 1, :name => "Rails"}
@project_manager = {:id => 5, :name => "David", :project_id =>1}
@project_managers = [@project_manager]

ActiveResource::HttpMock.respond_to do |mock|
  mock.get    "/projects/1.xml", {}, @project.to_xml(:root => 'project')
  mock.get    "/project_managers/5.xml", {}, @project_manager.to_xml(:root => 'project_manager')
  mock.get    "/project_managers.xml?project_id=1", {}, @project_managers.to_xml
end

class AssociationsTest < Test::Unit::TestCase

  def setup
    @project = Project.find(1)
    @project_manager = ProjectManager.find(5)
  end

  def test_has_one_should_add_a_resource_accessor
    assert @project.respond_to? :project_manager

    # should return the associated project_manager
    assert_equal @project_manager, @project.project_manager
  end

end

