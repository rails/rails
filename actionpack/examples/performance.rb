ENV['RAILS_ENV'] ||= 'production'

require File.expand_path('../../../load_paths', __FILE__)
require 'action_pack'
require 'action_controller'
require 'action_view'
require 'active_model'
require 'benchmark'

MyHash = Class.new(Hash)

Hash.class_eval do
  extend ActiveModel::Naming
  include ActiveModel::Conversion
end

class Runner
  def initialize(app, output)
    @app, @output = app, output
  end

  def puts(*)
    super if @output
  end

  def call(env)
    env['n'].to_i.times { @app.call(env) }
    @app.call(env).tap { |response| report(env, response) }
  end

  def report(env, response)
    return unless ENV["DEBUG"]
    out = env['rack.errors']
    out.puts response[0], response[1].to_yaml, '---'
    response[2].each { |part| out.puts part }
    out.puts '---'
  end

  def self.puts(*)
    super if @output
  end

  def self.print(*)
    super if @output
  end

  def self.app_and_env_for(action, n)
    env = Rack::MockRequest.env_for("/")
    env.merge!('n' => n, 'rack.input' => StringIO.new(''), 'rack.errors' => $stdout)
    app = lambda { |env| BasePostController.action(action).call(env) }
    return app, env
  end

  $ran = []

  def self.run(action, n, output = true)
    print "."
    STDOUT.flush
    @output = output
    label = action.to_s
    app, env = app_and_env_for(action, n)
    t = Benchmark.realtime { new(app, output).call(env) }
    $ran << [label, (t * 1000).to_i.to_s] if output
  end

  def self.done
    puts
    header, content = "", ""
    $ran.each do |k,v|
      size = [k.size, v.size].max + 1
      header << format("%#{size}s", k)
      content << format("%#{size}s", v)
    end
    puts header
    puts content
  end
end

ActionController::Base.logger = nil
ActionController::Base.config.compile_methods!
ActionView::Resolver.caching = ENV["RAILS_ENV"] == "production"

class BasePostController < ActionController::Base
  append_view_path "#{File.dirname(__FILE__)}/views"

  def overhead
    self.response_body = ''
  end

  def index
    render :text => ''
  end

  $OBJECT = {:name => "Hello my name is omg", :address => "333 omg"}

  def partial
    render :partial => "/collection", :object => $OBJECT
  end

  def partial_10
    render :partial => "/ten_partials"
  end

  def partial_100
    render :partial => "/hundred_partials"
  end

  $COLLECTION1 = []
  10.times do |i|
    $COLLECTION1 << { :name => "Hello my name is omg", :address => "333 omg" }
  end

  def coll_10
    render :partial => "/collection", :collection => $COLLECTION1
  end

  $COLLECTION2 = []
  100.times do |i|
    $COLLECTION2 << { :name => "Hello my name is omg", :address => "333 omg" }
  end

  def coll_100
    render :partial => "/collection", :collection => $COLLECTION2
  end

  def uniq_100
    render :partial => $COLLECTION2
  end

  $COLLECTION3 = []
  50.times do |i|
    $COLLECTION3 << {:name => "Hello my name is omg", :address => "333 omg"}
    $COLLECTION3 << MyHash.new(:name => "Hello my name is omg", :address => "333 omg")
  end

  def diff_100
    render :partial => $COLLECTION3
  end

  def template_1
    render :template => "template"
  end

  module Foo
    def omg
      "omg"
    end
  end

  helper Foo
end

N = (ENV['N'] || 1000).to_i
# ActionController::Base.use_accept_header = false

def run_all!(times, verbose)
  Runner.run(:overhead, times, verbose)
  Runner.run(:index,       times, verbose)
  Runner.run(:template_1,  times, verbose)
  Runner.run(:partial,     times, verbose)
  Runner.run(:partial_10,  times, verbose)
  Runner.run(:coll_10,     times, verbose)
  Runner.run(:partial_100, times, verbose)
  Runner.run(:coll_100,    times, verbose)
  Runner.run(:uniq_100,    times, verbose)
  Runner.run(:diff_100,    times, verbose)
end

unless ENV["PROFILE"]
  run_all!(1, false)

  (ENV["M"] || 1).to_i.times do
    $ran = []
    run_all!(N, true)
    Runner.done
  end
else
  Runner.run(ENV["PROFILE"].to_sym, 1, false)
  require "ruby-prof"
  RubyProf.start
  Runner.run(ENV["PROFILE"].to_sym, N, true)
  result = RubyProf.stop
  printer = RubyProf::CallStackPrinter.new(result)
  printer.print(File.open("output.html", "w"))
end