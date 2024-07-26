#!/usr/local/bin/ruby
require File.dirname(__FILE__) + '/../config/environments/production'
require 'generator'

unless ARGV.empty?
  rails_root = File.dirname(__FILE__) + '/..'
  name       = ARGV.shift
  actions    = ARGV
  Generator::Model.new(rails_root, name).generate
  Generator::Controller.new(rails_root, name, actions, :scaffold => true).generate
else
  puts <<-END_HELP

NAME
     new_crud - create a model and a controller scaffold

SYNOPSIS
     new_crud ModelName [action ...]

DESCRIPTION
     The new_crud generator takes the name of the new model as the
     first argument and an optional list of controller actions as the
     subsequent arguments.  All actions may be omitted since the controller
     will have scaffolding automatically set up for this model.

EXAMPLE
     new_crud Account

     This will generate an Account model and controller with scaffolding.
     Now create the accounts table in your database and browse to
     http://localhost/account/ -- voila, you're on Rails!

END_HELP
end
