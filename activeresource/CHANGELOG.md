## Rails 3.2.10 ##

## Rails 3.2.9 (Nov 12, 2012) ##

*   No changes.

## Rails 3.2.8 (Aug 9, 2012) ##

*   No changes.

## Rails 3.2.7 (Jul 26, 2012) ##

*   No changes.

## Rails 3.2.6 (Jun 12, 2012) ##

*   No changes.

## Rails 3.2.5 (Jun 1, 2012) ##

*   No changes.


## Rails 3.2.4 (May 31, 2012) ##

*   No changes.


## Rails 3.2.3 (March 30, 2012) ##

*   No changes.


## Rails 3.2.2 (March 1, 2012) ##

*   No changes.


## Rails 3.2.1 (January 26, 2012) ##

*   Documentation fixes.


## Rails 3.2.0 (January 20, 2012) ##

*   Redirect responses: 303 See Other and 307 Temporary Redirect now behave like
    301 Moved Permanently and 302 Found.  GH #3302.

    *Jim Herz*


## Rails 3.1.1 (October 7, 2011) ##

*   No changes.


## Rails 3.1.0 (August 30, 2011) ##

*   The default format has been changed to JSON for all requests. If you want to continue to use XML you will need to set `self.format = :xml` in the class. eg.

    class User < ActiveResource::Base    self.format = :xml
    end

## Rails 3.0.7 (April 18, 2011) ##

*   No changes.


*   Rails 3.0.6 (April 5, 2011)

*   No changes.


## Rails 3.0.5 (February 26, 2011) ##

*   No changes.


## Rails 3.0.4 (February 8, 2011) ##

*   No changes.


## Rails 3.0.3 (November 16, 2010) ##

*   No changes.


## Rails 3.0.2 (November 15, 2010) ##

*   No changes


## Rails 3.0.1 (October 15, 2010) ##

*   No Changes, just a version bump.


## Rails 3.0.0 (August 29, 2010) ##

*   JSON: set Base.include_root_in_json = true to include a root value in the JSON: {"post": {"title": ...}}. Mirrors the Active Record option.  *Santiago Pastorino*

*   Add support for errors in JSON format.  #1956 *Fabien Jakimowicz*

*   Recognizes 410 as Resource Gone. #2316 *Jordan Brough, Jatinder Singh*

*   More thorough SSL support.  #2370 *Roy Nicholson*

*   HTTP proxy support.  #2133 *Marshall Huss, Sébastien Dabet*


## 2.3.2 Final (March 15, 2009) ##

*   Nothing new, just included in 2.3.2


## 2.2.1 RC2 (November 14th, 2008) ##

*   Fixed that ActiveResource#post would post an empty string when it shouldn't be posting anything #525 *Paolo Angelini*


## 2.2.0 RC1 (October 24th, 2008) ##

*   Add ActiveResource::Base#to_xml and ActiveResource::Base#to_json. #1011 *Rasik Pandey, Cody Fauser*

*   Add ActiveResource::Base.find(:last). [#754 state:resolved] (Adrian Mugnolo)

*   Fixed problems with the logger used if the logging string included %'s [#840 state:resolved] (Jamis Buck)

*   Fixed Base#exists? to check status code as integer [#299 state:resolved] (Wes Oldenbeuving)


## 2.1.0 (May 31st, 2008) ##

*   Fixed response logging to use length instead of the entire thing (seangeo) *#27*

*   Fixed that to_param should be used and honored instead of hardcoding the id #11406 *gspiers*

*   Improve documentation. *Ryan Bigg, Jan De Poorter, Cheah Chu Yeow, Xavier Shay, Jack Danger Canty, Emilio Tagua, Xavier Noria,  Sunny Ripert*

*   Use HEAD instead of GET in exists? *bscofield*

*   Fix small documentation typo.  Closes #10670 *Luca Guidi*

*   find_or_create_resource_for handles module nesting.  #10646 *xavier*

*   Allow setting ActiveResource::Base#format before #site.  *Rick Olson*

*   Support agnostic formats when calling custom methods.  Closes #10635 *joerichsen*

*   Document custom methods.  #10589 *Cheah Chu Yeow*

*   Ruby 1.9 compatibility.  *Jeremy Kemper*


## 2.0.2 (December 16th, 2007) ##

*   Added more specific exceptions for 400, 401, and 403 (all descending from ClientError so existing rescues will work) #10326 *trek*

*   Correct empty response handling.  #10445 *seangeo*


## 2.0.1 (December 7th, 2007) ##

*   Don't cache net/http object so that ActiveResource is more thread-safe.  Closes #10142 *kou*

*   Update XML documentation examples to include explicit type attributes. Closes #9754 *Josh Susser*

*   Added one-off declarations of mock behavior [David Heinemeier Hansson]. Example:

        Before:
          ActiveResource::HttpMock.respond_to do |mock|
            mock.get "/people/1.xml", {}, "<person><name>David</name></person>"
          end

        Now:
          ActiveResource::HttpMock.respond_to.get "/people/1.xml", {}, "<person><name>David</name></person>"

*   Added ActiveResource.format= which defaults to :xml but can also be set to :json [David Heinemeier Hansson]. Example:

        class Person < ActiveResource::Base
          self.site   = "http://app/"
          self.format = :json
        end

        person = Person.find(1) # => GET http://app/people/1.json
        person.name = "David"
        person.save             # => PUT http://app/people/1.json {name: "David"}

        Person.format = :xml
        person.name = "Mary"
        person.save             # => PUT http://app/people/1.json <person><name>Mary</name></person>

*   Fix reload error when path prefix is used.  #8727 *Ian Warshak*

*   Remove ActiveResource::Struct because it hasn't proven very useful. Creating a new ActiveResource::Base subclass is often less code and always clearer.  #8612 *Josh Peek*

*   Fix query methods on resources. *Cody Fauser*

*   pass the prefix_options to the instantiated record when using find without a specific id. Closes #8544 *Eloy Duran*

*   Recognize and raise an exception on 405 Method Not Allowed responses.  #7692 *Josh Peek*

*   Handle string and symbol param keys when splitting params into prefix params and query params.

        Comment.find(:all, :params => { :article_id => 5, :page => 2 }) or Comment.find(:all, :params => { 'article_id' => 5, :page => 2 })

*   Added find-one with symbol [David Heinemeier Hansson]. Example: Person.find(:one, :from => :leader) # => GET /people/leader.xml

*   BACKWARDS INCOMPATIBLE: Changed the finder API to be more extensible with :params and more strict usage of scopes [David Heinemeier Hansson]. Changes:

        Person.find(:all, :title => "CEO")      ...becomes: Person.find(:all, :params => { :title => "CEO" })
        Person.find(:managers)                  ...becomes: Person.find(:all, :from => :managers)
        Person.find("/companies/1/manager.xml") ...becomes: Person.find(:one, :from => "/companies/1/manager.xml")

*   Add support for setting custom headers per Active Resource model *Rick Olson*

    class Project
        headers['X-Token'] = 'foo'
    end

    \# makes the GET request with the custom X-Token header
    Project.find(:all)

*   Added find-by-path options to ActiveResource::Base.find [David Heinemeier Hansson]. Examples:

        employees = Person.find(:all, :from => "/companies/1/people.xml") # => GET /companies/1/people.xml
        manager   = Person.find("/companies/1/manager.xml")               # => GET /companies/1/manager.xml


*   Added support for using classes from within a single nested module [David Heinemeier Hansson]. Example:

        module Highrise
          class Note < ActiveResource::Base
            self.site = "http://37s.sunrise.i:3000"
          end

          class Comment < ActiveResource::Base
            self.site = "http://37s.sunrise.i:3000"
          end
        end

    assert_kind_of Highrise::Comment, Note.find(1).comments.first


*   Added load_attributes_from_response as a way of loading attributes from other responses than just create *David Heinemeier Hansson*

        class Highrise::Task < ActiveResource::Base
          def complete
            load_attributes_from_response(post(:complete))
          end
        end

    ...will set "done_at" when complete is called.


*   Added support for calling custom methods #6979 *rwdaigle*

        Person.find(:managers)    # => GET /people/managers.xml
        Kase.find(1).post(:close) # => POST /kases/1/close.xml

*   Remove explicit prefix_options parameter for ActiveResource::Base#initialize. *Rick Olson*
    ActiveResource splits the prefix_options from it automatically.

*   Allow ActiveResource::Base.delete with custom prefix. *Rick Olson*

*   Add ActiveResource::Base#dup *Rick Olson*

*   Fixed constant warning when fetching the same object multiple times *David Heinemeier Hansson*

*   Added that saves which get a body response (and not just a 201) will use that response to update themselves *David Heinemeier Hansson*

*   Disregard namespaces from the default element name, so Highrise::Person will just try to fetch from "/people", not "/highrise/people" *David Heinemeier Hansson*

*   Allow array and hash query parameters.  #7756 *Greg Spurrier*

*   Loading a resource preserves its prefix_options.  #7353 *Ryan Daigle*

*   Carry over the convenience of #create from ActiveRecord.  Closes #7340.  *Ryan Daigle*

*   Increase ActiveResource::Base test coverage.  Closes #7173, #7174 *Rich Collins*

*   Interpret 422 Unprocessable Entity as ResourceInvalid.  #7097 *dkubb*

*   Mega documentation patches. #7025, #7069 *rwdaigle*

*   Base.exists?(id, options) and Base#exists? check whether the resource is found.  #6970 *rwdaigle*

*   Query string support.  *untext, Jeremy Kemper*
        # GET /forums/1/topics.xml?sort=created_at
        Topic.find(:all, :forum_id => 1, :sort => 'created_at')

*   Base#==, eql?, and hash methods. == returns true if its argument is identical to self or if it's an instance of the same class, is not new?, and has the same id. eql? is an alias for ==. hash delegates to id.  *Jeremy Kemper*

*   Allow subclassed resources to share the site info *Rick Olson, Jeremy Kemper*
    d        class BeastResource < ActiveResource::Base
          self.site = 'http://beast.caboo.se'
        end

        class Forum < BeastResource
          # taken from BeastResource
          # self.site = 'http://beast.caboo.se'
        end

        class Topic < BeastResource
          self.site += '/forums/:forum_id'
        end

*   Fix issues with ActiveResource collection handling.  Closes #6291. *bmilekic*

*   Use attr_accessor_with_default to dry up attribute initialization. References #6538. *Stuart Halloway*

*   Add basic logging support for logging outgoing requests. *Jamis Buck*

*   Add Base.delete for deleting resources without having to instantiate them first. *Jamis Buck*

*   Make #save behavior mimic AR::Base#save (true on success, false on failure). *Jamis Buck*

*   Add Basic HTTP Authentication to ActiveResource (closes #6305). *jonathan*

*   Extracted #id_from_response as an entry point for customizing how a created resource gets its own ID.
    By default, it extracts from the Location response header.

*   Optimistic locking: raise ActiveResource::ResourceConflict on 409 Conflict response. *Jeremy Kemper*

        # Example controller action
        def update
          @person.save!
        rescue ActiveRecord::StaleObjectError
          render :xml => @person.reload.to_xml, :status => '409 Conflict'
        end

*   Basic validation support *Rick Olson*

    Parses the xml response of ActiveRecord::Errors#to_xml with a similar interface to ActiveRecord::Errors.

        render :xml => @person.errors.to_xml, :status => '400 Validation Error'

*   Deep hashes are converted into collections of resources.  *Jeremy Kemper*
        Person.new :name => 'Bob',
                   :address => { :id => 1, :city => 'Portland' },
                   :contacts => [{ :id => 1 }, { :id => 2 }]
    Looks for Address and Contact resources and creates them if unavailable.
    So clients can fetch a complex resource in a single request if you e.g.
        render :xml => @person.to_xml(:include => [:address, :contacts])
    in your controller action.

*   Major updates *Rick Olson*

    * Add full support for find/create/update/destroy
    * Add support for specifying prefixes.
    * Allow overriding of element_name, collection_name, and primary key
    * Provide simpler HTTP mock interface for testing

        # rails routing code
        map.resources :posts do |post|
          post.resources :comments
        end

        # ActiveResources
        class Post < ActiveResource::Base
          self.site = "http://37s.sunrise.i:3000/"
        end

        class Comment < ActiveResource::Base
          self.site = "http://37s.sunrise.i:3000/posts/:post_id/"
        end

        @post     = Post.find 5
        @comments = Comment.find :all, :post_id => @post.id

        @comment  = Comment.new({:body => 'hello world'}, {:post_id => @post.id})
        @comment.save

*   Base.site= accepts URIs. 200...400 are valid response codes. PUT and POST request bodies default to ''. *Jeremy Kemper*

*   Initial checkin: object-oriented client for restful HTTP resources which follow the Rails convention. *David Heinemeier Hansson*
