#!/usr/local/bin/ruby

$:.unshift(File.dirname(__FILE__) + "/../lib")

require "action_controller"

Post = Struct.new("Post", :title, :body)

class BlogController < ActionController::Base
  before_filter :initialize_session_storage

  def index
    @posts = @session["posts"]
    
    render_template <<-"EOF"
      <html><body>
      <%= flash["alert"] %>
      <h1>Posts</h1>
      <% @posts.each do |post| %>
        <p><b><%= post.title %></b><br /><%= post.body %></p>
      <% end %>

      <h1>Create post</h1>
      <form action="create">
        Title: <input type="text" name="post[title]"><br>
        Body: <textarea name="post[body]"></textarea><br>
        <input type="submit" value="save">
      </form>
      
      </body></html>
    EOF
  end
  
  def create
    @session["posts"].unshift(Post.new(params[:post][:title], params[:post][:body]))
    flash["alert"] = "New post added!"
    redirect_to :action => "index"
  end
  
  private
    def initialize_session_storage
      @session["posts"] = [] if @session["posts"].nil?
    end
end

ActionController::Base.view_paths = [ File.dirname(__FILE__) ]
# ActionController::Base.logger = Logger.new("debug.log") # Remove first comment to turn on logging in current dir

begin
  BlogController.process_cgi(CGI.new) if $0 == __FILE__
rescue => e
  CGI.new.out { "#{e.class}: #{e.message}" }
end
