require 'abstract_unit'
require "fixtures/project"

class ProjectManager < ActiveResource::Base
end

class Project < ActiveResource::Base
  has_one :project_manager
end

class AssociationsTest < Test::Unit::TestCase

  def setup
    @project = Project.new
  end

  def test_has_one_should_add_a_resource_accessor
    assert @project.respond_to? :project_manager
  end
end

