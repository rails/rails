require 'meta_weblog_api'

class MetaWeblogService < ActionWebService::Base
  web_service_api MetaWeblogAPI

  def initialize
    @postid = 0
  end

  def newPost(id, user, pw, struct, publish)
    $stderr.puts "id=#{id} user=#{user} pw=#{pw}, struct=#{struct.inspect} [#{publish}]"
    (@postid += 1).to_s
  end

  def editPost(post_id, user, pw, struct, publish)
    $stderr.puts "id=#{post_id} user=#{user} pw=#{pw} struct=#{struct.inspect} [#{publish}]"
    true
  end

  def getPost(post_id, user, pw)
    $stderr.puts "get post #{post_id}"
    Blog::Post.new(:title => 'hello world', :description => 'first post!')
  end

  def getCategories(id, user, pw)
    $stderr.puts "categories for #{user}"
    cat = Blog::Category.new(
      :description => 'Tech',
      :htmlUrl     => 'http://blog/tech',
      :rssUrl      => 'http://blog/tech.rss')
    [cat]
  end

  def getRecentPosts(id, user, pw, num)
    $stderr.puts "recent #{num} posts for #{user} on blog #{id}"
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
