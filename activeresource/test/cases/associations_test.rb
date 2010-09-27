require 'abstract_unit'
require "fixtures/project"

class ProjectManager < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
end

class Project < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  has_one :project_manager
end

@project = <<-eof.strip
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <project>
      <id type=\"integer\">1</id>
      <name>Rails</name>
      <project_manager_id>5</project_manager_id>
    </project>
eof

@project_manager = <<-eof.strip
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <project_manager>
      <id type=\"integer\">5</id>
      <name>David</name>
    </project_manager>
eof

ActiveResource::HttpMock.respond_to do |mock|
  mock.get    "/projects/1.xml", {}, @project
  mock.get    "/project_managers/5.xml", {}, @project_manager
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

