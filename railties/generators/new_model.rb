#!/usr/local/bin/ruby

def create_model_class(model_name)
  File.open("app/models/" + model_name.downcase  + ".rb", "w", 0777) do |model_file|
    model_file.write <<EOF
require 'active_record'

class #{model_name} < ActiveRecord::Base
end
EOF
  end
end

def create_test_class(model_name)
    File.open("test/unit/" + model_name.downcase  + "_test.rb", "w", 0777) do |test_file|
        test_file.write <<EOF
require File.dirname(__FILE__) + '/../unit_test_helper'
require '#{model_name.downcase}'

class #{model_name}Test < Test::Unit::TestCase
  def setup
    @#{model_name.downcase}s = create_fixtures "#{model_name.downcase}s"
  end

  def test_something
    assert true, "Test implementation missing"
  end
end
EOF
    end
end

def create_fixtures_directory(model_name)
  Dir.mkdir("test/fixtures/" + model_name.downcase + "s") rescue puts "Fixtures directory already exists"
end


if !ARGV.empty?
  model_name = ARGV.shift

  create_model_class(model_name)
  create_test_class(model_name)
  create_fixtures_directory(model_name)
else
  puts <<-HELP

NAME
     new_model - create model stub files

SYNOPSIS
     new_model [model_name]

DESCRIPTION
     The new_model generator takes the name of the new model and generates a model
     file in app/models that decents from ActiveRecord::Base but is otherwise empty.
     It then creates a model test suite in test/unit with one failing
     test case. Finally, it creates fixture directory in test/fixtures.
     
EXAMPLE
     new_model Account
     
     This will generate a Account class in app/models/account.rb, a AccountTest in 
     test/unit/account_test.rb, and the directory test/fixtures/account.

HELP
end