# point your client at http://project_url/blog/api to test
# this

# structures as defined by the metaWeblog/blogger
# specifications.
module Blog
  class Enclosure < ActionWebService::Struct
    member :url,    :string
    member :length, :int
    member :type,   :string
  end

  class Source < ActionWebService::Struct
    member :url,  :string
    member :name, :string
  end

  class Post < ActionWebService::Struct
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

  class Blog < ActionWebService::Struct
    member :url,      :string
    member :blogid,   :string
    member :blogName, :string
  end
end

# skeleton metaWeblog API
class MetaWeblogAPI < ActionWebService::API::Base
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
  web_service_api MetaWeblogAPI

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
    blog = Blog::Blog.new(
      :url =>'http://blog.xeraph.org',
      :blogid => 'sttm',
      :blogName => 'slave to the machine'
    )
    [blog]
  end

  def getRecentPosts
    $stderr.puts "Returning recent posts (%d requested)" % @params['numberOfPosts']
    post1 = Blog::Post.new(
      :title => 'first post!',
      :link => 'http://blog.xeraph.org/testOne.html',
      :description => 'this is the first post'
    )
    post2 = Blog::Post.new(
      :title => 'second post!',
      :link => 'http://blog.xeraph.org/testTwo.html',
      :description => 'this is the second post'
    )
    [post1, post2]
  end
end
