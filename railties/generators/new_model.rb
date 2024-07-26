#!/usr/local/bin/ruby
require File.dirname(__FILE__) + '/../config/environments/production'
require 'generator'

if ARGV.size == 1
  rails_root = File.dirname(__FILE__) + '/..'
  name = ARGV.shift
  Generator::Model.new(rails_root, name).generate
else
  puts <<-HELP

NAME
     new_model - create model stub files

SYNOPSIS
     new_model ModelName

DESCRIPTION
     The new_model generator takes a model name (in CamelCase) and generates
     a new, empty model in app/models, a test suite in test/unit with one
     failing test case, and a fixtures directory in test/fixtures.

EXAMPLE
     new_model Account

     This will generate an Account class in app/models/account.rb, an
     AccountTest in test/unit/account_test.rb, and the directory
     test/fixtures/account.

HELP
end
