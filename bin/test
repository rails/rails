#!/usr/bin/env ruby
# frozen_string_literal: true

raw_directory = ARGV.first.split("/").first
directory = File.join(raw_directory, "/")
args = ARGV.filter_map do |arg|
  if arg == raw_directory
    nil
  else
    arg.delete_prefix(directory)
  end
end

ENV["RAILS_TEST_PWD"] = Dir.pwd
Dir.chdir(directory)
exec("bin/test", *args)
