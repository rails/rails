#!/usr/bin/env ruby
require "fileutils"
include FileUtils

commands = [
  'mysql -e "create database activerecord_unittest;"',
  'mysql -e "create database activerecord_unittest2;"',
  'psql  -c "create database activerecord_unittest;" -U postgres',
  'psql  -c "create database activerecord_unittest2;" -U postgres'
]

commands.each do |command|
  system("#{command} > /dev/null 2>&1")
end

class Build
  MAP = {
    "railties" => "railties",
    "ap"       => "actionpack",
    "am"       => "actionmailer",
    "amo"      => "activemodel",
    "as"       => "activesupport",
    "ar"       => "activerecord",
    "av"       => "actionview",
    "aj"       => "activejob",
    "ac"       => "actioncable",
    "guides"   => "guides"
  }

  attr_reader :component, :options

  def initialize(component, options = {})
    @component = component
    @options = options
  end

  def run!(options = {})
    self.options.update(options)
    Dir.chdir(dir) do
      announce(heading)
      if guides?
        run_bug_report_templates
      else
        rake(*tasks)
      end
    end
  end

  def announce(heading)
    puts "\n\e[1;33m[Travis CI] #{heading}\e[m\n"
  end

  def heading
    heading = [gem]
    heading << "with #{adapter}" if activerecord?
    heading << "in isolation" if isolated?
    heading << "integration" if integration?
    heading.join(" ")
  end

  def tasks
    if activerecord?
      tasks = ["#{adapter}:#{'isolated_' if isolated?}test"]
      case adapter
      when "mysql2"
        tasks.unshift "db:mysql:rebuild"
      when "postgresql"
        tasks.unshift "db:postgresql:rebuild"
      end
      tasks
    else
      ["test", ("isolated" if isolated?), ("integration" if integration?)].compact.join(":")
    end
  end

  def key
    key = [gem]
    key << adapter if activerecord?
    key << "isolated" if isolated?
    key.join(":")
  end

  def activesupport?
    gem == "activesupport"
  end

  def activerecord?
    gem == "activerecord"
  end

  def guides?
    gem == "guides"
  end

  def isolated?
    options[:isolated]
  end

  def integration?
    component.split(":").last == "integration"
  end

  def gem
    MAP[component.split(":").first]
  end
  alias :dir :gem

  def adapter
    component.split(":").last
  end

  def rake(*tasks)
    tasks.each do |task|
      cmd = "bundle exec rake #{task}"
      puts "Running command: #{cmd}"
      return false unless system(env, cmd)
    end
    true
  end

  def env
    if activesupport? && !isolated?
      # There is a known issue with the listen tests that causes files to be
      # incorrectly GC'ed even when they are still in-use. The current solution
      # is to only run them in isolation to avoid randomly failing our test suite.
      { "LISTEN" => "0" }
    else
      {}
    end
  end

  def run_bug_report_templates
    Dir.glob("bug_report_templates/*.rb").all? do |file|
      system(Gem.ruby, "-w", file)
    end
  end
end

if ENV["GEM"] == "aj:integration"
  ENV["QC_DATABASE_URL"]  = "postgres://postgres@localhost/active_jobs_qc_int_test"
  ENV["QUE_DATABASE_URL"] = "postgres://postgres@localhost/active_jobs_que_int_test"
end

results = {}

ENV["GEM"].split(",").each do |gem|
  [false, true].each do |isolated|
    next if ENV["TRAVIS_PULL_REQUEST"] && ENV["TRAVIS_PULL_REQUEST"] != "false" && isolated
    next if gem == "railties" && isolated
    next if gem == "ac" && isolated
    next if gem == "ac:integration" && isolated
    next if gem == "aj:integration" && isolated
    next if gem == "guides" && isolated

    build = Build.new(gem, isolated: isolated)
    results[build.key] = build.run!

  end
end

failures = results.select { |key, value| !value  }

if failures.empty?
  puts
  puts "Rails build finished successfully"
  exit(true)
else
  puts
  puts "Rails build FAILED"
  puts "Failed components: #{failures.map(&:first).join(', ')}"
  exit(false)
end
