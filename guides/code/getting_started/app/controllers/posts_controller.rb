class PostsController < ApplicationController

  def new
  end

  def create
    @post = Post.new(params[:post])

    @post.save
    redirect_to :action => :index
  end
end
