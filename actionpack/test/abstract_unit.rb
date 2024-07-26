$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'action_controller'

require 'action_controller/test_process'

class MockTemplate < ActionView::ERbTemplate
  attr_reader :template_name

  def initialize(template_root, parameters = {}, controller = nil)
    super
  end

  def render_file(template_path, status = "200 OK") 
    @template_name, @status = template_path, status
  end
end

ActionController::Base.template_class = MockTemplate
ActionController::Base.logger = nil
ActionController::Base.ignore_missing_templates = true
