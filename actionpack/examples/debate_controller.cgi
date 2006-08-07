#!/usr/local/bin/ruby

$:.unshift(File.dirname(__FILE__) + "/../lib")

require "action_controller"

Topic = Struct.new("Topic", :id, :title, :body, :replies)
Reply = Struct.new("Reply", :body)

class DebateService
  attr_reader :topics

  def initialize()         @topics = [] end
  def create_topic(data)   topics.unshift(Topic.new(next_topic_id, data["title"], data["body"], [])) end
  def create_reply(data)   find_topic(data["topic_id"]).replies << Reply.new(data["body"]) end
  def find_topic(topic_id) topics.select { |topic| topic.id == topic_id.to_i }.first end
  def next_topic_id()      topics.first.id + 1 end
end

class DebateController < ActionController::Base
  before_filter :initialize_session_storage

  def index
    @topics = @debate.topics
  end
  
  def topic
    @topic = @debate.find_topic(params[:id])
  end
  
  # def new_topic() end <-- This is not needed as the template doesn't require any assigns

  def create_topic
    @debate.create_topic(params[:topic])
    redirect_to :action => "index"
  end

  def create_reply
    @debate.create_reply(params[:reply])
    redirect_to :action => "topic", :path_params => { "id" => params[:reply][:topic_id] }
  end
    
  private
    def initialize_session_storage
      @session["debate"] = DebateService.new if @session["debate"].nil?
      @debate = @session["debate"]
    end
end

ActionController::Base.template_root = File.dirname(__FILE__)
# ActionController::Base.logger = Logger.new("debug.log") # Remove first comment to turn on logging in current dir

begin
  DebateController.process_cgi(CGI.new) if $0 == __FILE__
rescue => e
  CGI.new.out { "#{e.class}: #{e.message}" }
end
