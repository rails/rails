# structures as defined by the metaWeblog/blogger
# specifications.
module Blog
  class Enclosure < ActionService::Struct
    member :url,    :string
    member :length, :int
    member :type,   :string
  end

  class Source < ActionService::Struct
    member :url,  :string
    member :name, :string
  end

  class Post < ActionService::Struct
    member :title,       :string
    member :link,        :string
    member :description, :string
    member :author,      :string
    member :category,    :string
    member :comments,    :string
    member :enclosure,   Enclosure
    member :guid,        :string
    member :pubDate,     :string
    member :source,      Source
  end

  class Blog < ActionService::Struct
    member :url,      :string
    member :blogid,   :string
    member :blogName, :string
  end
end

# skeleton metaWeblog API
class MetaWeblogAPI < ActionService::API::Base
  inflect_names false

  api_method :newPost, :returns => [:string], :expects => [
    {:blogid=>:string},
    {:username=>:string},
    {:password=>:string},
    {:struct=>Blog::Post},
    {:publish=>:bool},
  ]

  api_method :editPost, :returns => [:bool], :expects => [
    {:postid=>:string},
    {:username=>:string},
    {:password=>:string},
    {:struct=>Blog::Post},
    {:publish=>:bool},
  ]

  api_method :getPost, :returns => [Blog::Post], :expects => [
    {:postid=>:string},
    {:username=>:string},
    {:password=>:string},
  ]

  api_method :getUsersBlogs, :returns => [[Blog::Blog]], :expects => [
    {:appkey=>:string},
    {:username=>:string},
    {:password=>:string},
  ]

  api_method :getRecentPosts, :returns => [[Blog::Post]], :expects => [
    {:blogid=>:string},
    {:username=>:string},
    {:password=>:string},
    {:numberOfPosts=>:int},
  ]
end

class BlogController < ApplicationController
  service_api MetaWeblogAPI

  def initialize
    @postid = 0
  end

  def newPost
    $stderr.puts 'Creating post: username=%s password=%s struct=%s' % [
      @params['username'],
      @params['password'],
      @params['struct'].inspect
    ]
    (@postid += 1).to_s
  end

  def editPost
    $stderr.puts 'Editing post: username=%s password=%s struct=%s' % [
      @params['username'],
      @params['password'],
      @params['struct'].inspect
    ]
    true
  end

  def getUsersBlogs
    $stderr.puts "Returning user %s's blogs" % @params['username']
    blog = Blog::Blog.new
    blog.url = 'http://blog.xeraph.org'
    blog.blogid = 'sttm'
    blog.blogName = 'slave to the machine'
    [blog]
  end

  def getRecentPosts
    $stderr.puts "Returning recent posts (%d requested)" % @params['numberOfPosts']
    post1 = Blog::Post.new
    post1.title = 'first post!'
    post1.link = 'http://blog.xeraph.org/testOne.html'
    post1.description = 'this is the first post'
    post2 = Blog::Post.new
    post2.title = 'second post!'
    post2.link = 'http://blog.xeraph.org/testTwo.html'
    post2.description = 'this is the second post'
    [post1, post2]
  end
end
