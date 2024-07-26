#!/usr/local/bin/ruby

def create_controller_class(controller_name, show_actions)
  File.open("app/controllers/" + controller_name.downcase  + "_controller.rb", "w", 0777) do |controller_file|
    controller_file.write <<EOF
require 'action_controller'
require '#{controller_name.downcase}_helper'

class #{controller_name}Controller < ActionController::Base
  include #{controller_name}Helper

#{show_actions.collect { |action| "  def #{action}\n  end" }.join "\n\n" }
end
EOF
  end
end

def create_helper_class(controller_name)
  File.open("app/helpers/" + controller_name.downcase  + "_helper.rb", "w", 0777) do |helper_file|
    helper_file.write <<EOF
module #{controller_name}Helper
  def self.append_features(controller) #:nodoc:
    controller.ancestors.include?(ActionController::Base) ? controller.add_template_helper(self) : super
  end
end
EOF
  end
end

def create_templates(controller_name, show_actions)
  Dir.mkdir("app/views/#{controller_name.downcase}") rescue nil
  show_actions.each { |action| File.open("app/views/#{controller_name.downcase}/#{action}.rhtml", "w", 0777) do |template_file|
    template_file.write <<EOF
<html>
<body>
<h1>#{controller_name}##{action}</h1>
</body>
</html>
EOF
  end }
end

def create_test_class(controller_name)
  File.open("test/functional/" + controller_name.downcase  + "_controller_test.rb", "w", 0777) do |test_file|
    test_file.write <<EOF
require File.dirname(__FILE__) + '/../functional_test_helper'
require '#{controller_name.downcase}_controller'

# Raise errors beyond the default web-based presentation
class #{controller_name}Controller; def rescue_action(e) raise e end; end

class #{controller_name}ControllerTest < Test::Unit::TestCase
  def setup
    @request = ActionController::TestRequest.new
    @request.host = ""
  end

  # def test_index
  #   @request.action = "index"
  #   assert_equal "#{controller_name.downcase}/index", #{controller_name}Controller.process_test(@request).template.first_render
  # end

  def test_truth
    assert true, "Test implementation missing"
  end
end
EOF
  end
end


if !ARGV.empty?
  controller_name = ARGV[0]
  show_actions    = ARGV[1..-1]

  create_controller_class(controller_name, show_actions)
  create_helper_class(controller_name)
  create_templates(controller_name, show_actions)
  create_test_class(controller_name)
else
  puts <<-END_HELP

NAME
     new_controller - create controller and view stub files

SYNOPSIS
     new_controller [controller_name] [view_name ...]

DESCRIPTION
     The new_controller generator takes the name of the new controller as the
     first argument and a variable number of view names as subsequent arguments.
     The controller name should be supplied without a "Controller" suffix. The
     generator will add that itself.
     
     From the passed arguments, new_controller generates a controller file in
     app/controllers with a render action for each of the view names passed.
     It then creates a controller test suite in test/functional with one failing
     test case. Finally, it creates an HTML stub for each of the view names in
     app/views under a directory with the same name as the controller.
     
EXAMPLE
     new_controller Blog list display new edit
     
     This will generate a BlogController class in
     app/controllers/blog_controller.rb, a BlogHelper class in
     app/helpers/blog_helper.rb and a BlogControllerTest in
     test/functional/blog_controller_test.rb. It will also create list.rhtml,
     display.rhtml, new.rhtml, and edit.rhtml in app/views/blog.
     
     The BlogController class will have the following methods: list, display, new, edit.
     Each will default to render the associated template file.
END_HELP
end