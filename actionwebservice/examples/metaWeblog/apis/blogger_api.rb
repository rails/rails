#
# see the blogger API spec at http://www.blogger.com/developers/api/1_docs/
# note that the method signatures are subtly different to metaWeblog, they
# are not identical. take care to ensure you handle the different semantics
# properly if you want to support blogger API too, to get maximum compatibility.
#

module Blog
  class Blog < ActionWebService::Struct
    member :url,      :string
    member :blogid,   :string
    member :blogName, :string
  end

  class User < ActionWebService::Struct
    member :nickname,  :string
    member :userid,    :string
    member :url,       :string
    member :email,     :string
    member :lastname,  :string
    member :firstname, :string
  end
end

#
# blogger
#
class BloggerAPI < ActionWebService::API::Base
  inflect_names false

  api_method :newPost, :returns => [:string], :expects => [
    {:appkey=>:string},
    {:blogid=>:string},
    {:username=>:string},
    {:password=>:string},
    {:content=>:string},
    {:publish=>:bool}
  ]

  api_method :editPost, :returns => [:bool], :expects => [
    {:appkey=>:string},
    {:postid=>:string},
    {:username=>:string},
    {:password=>:string},
    {:content=>:string},
    {:publish=>:bool}
  ]

  api_method :getUsersBlogs, :returns => [[Blog::Blog]], :expects => [
    {:appkey=>:string},
    {:username=>:string},
    {:password=>:string}
  ]

  api_method :getUserInfo, :returns => [Blog::User], :expects => [
    {:appkey=>:string},
    {:username=>:string},
    {:password=>:string}
  ]
end
