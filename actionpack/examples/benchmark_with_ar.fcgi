#!/usr/local/bin/ruby

begin

$:.unshift(File.dirname(__FILE__) + "/../lib")
$:.unshift(File.dirname(__FILE__) + "/../../../edge/activerecord/lib")

require 'fcgi'
require 'action_controller'
require 'action_controller/test_process'

require 'active_record'

class Post < ActiveRecord::Base; end

ActiveRecord::Base.establish_connection(:adapter => "mysql", :database => "basecamp")

SESSION_OPTIONS = { "database_manager" => CGI::Session::MemoryStore }

class TestController < ActionController::Base
  def index
    render_template <<-EOT
    <% for post in Post.find_all(nil,nil,100) %>
      <%= post.title %>
    <% end %>
    EOT
  end

  def show_one
    render_template <<-EOT
      <%= Post.find_first.title %>
    EOT
  end
  
  def text
    render_text "hello world"
  end

  def erb_text
    render_template "hello <%= 'world' %>"
  end
  
  def erb_loop
    render_template <<-EOT
    <% for post in 1..100 %>
      <%= post %>
    <% end %>
    EOT
  end
  
  def rescue_action(e) puts e.message + e.backtrace.join("\n") end
end

if ARGV.empty? && ENV["REQUEST_URI"]
  FCGI.each_cgi do |cgi| 
    TestController.process(ActionController::CgiRequest.new(cgi, SESSION_OPTIONS), ActionController::CgiResponse.new(cgi)).out
  end
else
  if ARGV.empty?
    cgi = CGI.new
  end

  require 'benchmark'
  require 'profile' if ARGV[2] == "profile"
    
  RUNS = ARGV[1] ? ARGV[1].to_i : 50
  
  runtime = Benchmark::measure {
    RUNS.times { 
      if ARGV.empty?
        TestController.process(ActionController::CgiRequest.new(cgi, SESSION_OPTIONS), ActionController::CgiResponse.new(cgi))
      else
        response = TestController.process_test(
          ActionController::TestRequest.new({"action" => ARGV[0]})
        )
        puts(response.body) if ARGV[2] == "show"
      end
    }
  }
  
  puts "Runs: #{RUNS}"
  puts "Avg. runtime: #{runtime.real / RUNS}"
  puts "Requests/second: #{RUNS / runtime.real}"
end

rescue Exception => e
  # CGI.new.out { "<pre>" + e.message + e.backtrace.join("\n") + "</pre>" }
  $stderr << e.message + e.backtrace.join("\n")
end