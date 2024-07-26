#!/usr/local/bin/ruby
require File.dirname(__FILE__) + '/../config/environments/production'
require 'generator'

unless ARGV.empty?
  rails_root = File.dirname(__FILE__) + '/..'
  name       = ARGV.shift
  actions    = ARGV
  Generator::Controller.new(rails_root, name, actions).generate
else
  puts <<-END_HELP

NAME
     new_controller - create controller and view stub files

SYNOPSIS
     new_controller ControllerName action [action ...]

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
