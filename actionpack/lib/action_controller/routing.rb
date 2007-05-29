require 'cgi'
require 'uri'
require 'action_controller/polymorphic_routes'

class Object
  def to_param
    to_s
  end
end

class TrueClass
  def to_param
    self
  end
end

class FalseClass
  def to_param
    self
  end
end

class NilClass
  def to_param
    self
  end
end

class Regexp #:nodoc:
  def number_of_captures
    Regexp.new("|#{source}").match('').captures.length
  end
  
  class << self
    def optionalize(pattern)
      case unoptionalize(pattern)
        when /\A(.|\(.*\))\Z/ then "#{pattern}?"
        else "(?:#{pattern})?"
      end
    end
    
    def unoptionalize(pattern)
      [/\A\(\?:(.*)\)\?\Z/, /\A(.|\(.*\))\?\Z/].each do |regexp|
        return $1 if regexp =~ pattern
      end
      return pattern
    end
  end
end

module ActionController
  # == Routing 
  #
  # The routing module provides URL rewriting in native Ruby. It's a way to
  # redirect incoming requests to controllers and actions. This replaces
  # mod_rewrite rules. Best of all Rails' Routing works with any web server. 
  # Routes are defined in routes.rb in your RAILS_ROOT/config directory.
  #
  # Consider the following route, installed by Rails when you generate your 
  # application:
  #
  #   map.connect ':controller/:action/:id'
  #
  # This route states that it expects requests to consist of a 
  # :controller followed by an :action that in turns is fed by some :id 
  #
  # Suppose you get an incoming request for <tt>/blog/edit/22</tt>, you'll end up 
  # with:
  #
  #   params = { :controller => 'blog',
  #              :action     => 'edit' 
  #              :id         => '22'
  #           }
  #
  # Think of creating routes as drawing a map for your requests. The map tells 
  # them where to go based on some predefined pattern:
  #
  #  ActionController::Routing::Routes.draw do |map|
  #   Pattern 1 tells some request to go to one place
  #   Pattern 2 tell them to go to another
  #   ...
  #  end
  #
  # The following symbols are special:
  #
  #   :controller maps to your controller name
  #   :action     maps to an action with your controllers
  #   
  # Other names simply map to a parameter as in the case of +:id+.
  #    
  # == Route priority
  #
  # Not all routes are created equally. Routes have priority defined by the 
  # order of appearance of the routes in the routes.rb file. The priority goes
  # from top to bottom. The last route in that file is at the lowest priority
  # will be applied last. If no route matches, 404 is returned.
  #
  # Within blocks, the empty pattern goes first i.e. is at the highest priority.
  # In practice this works out nicely:
  #
  #  ActionController::Routing::Routes.draw do |map| 
  #    map.with_options :controller => 'blog' do |blog|
  #      blog.show    '',  :action => 'list'
  #    end
  #    map.connect ':controller/:action/:view 
  #  end
  #
  # In this case, invoking blog controller (with an URL like '/blog/') 
  # without parameters will activate the 'list' action by default.
  #
  # == Defaults routes and default parameters
  #
  # Setting a default route is straightforward in Rails because by appending a
  # Hash to the end of your mapping you can set default parameters.
  #
  # Example:
  #  ActionController::Routing:Routes.draw do |map|
  #    map.connect ':controller/:action/:id', :controller => 'blog'
  #  end
  #
  # This sets up  +blog+ as the default controller if no other is specified. 
  # This means visiting '/' would invoke the blog controller.
  #
  # More formally, you can define defaults in a route with the +:defaults+ key.
  #   
  #   map.connect ':controller/:id/:action', :action => 'show', :defaults => { :page => 'Dashboard' }
  #
  # == Named routes
  #
  # Routes can be named with the syntax <tt>map.name_of_route options</tt>,
  # allowing for easy reference within your source as +name_of_route_url+
  # for the full URL and +name_of_route_path+ for the URI path.
  #
  # Example:
  #   # In routes.rb
  #   map.login 'login', :controller => 'accounts', :action => 'login'
  #
  #   # With render, redirect_to, tests, etc.
  #   redirect_to login_url
  #
  # Arguments can be passed as well.
  #
  #   redirect_to show_item_path(:id => 25)
  #
  # Use <tt>map.root</tt> as a shorthand to name a route for the root path ""
  #
  #   # In routes.rb
  #   map.root :controller => 'blogs'
  #
  #   # would recognize http://www.example.com/ as
  #   params = { :controller => 'blogs', :action => 'index' }
  #
  #   # and provide these named routes
  #   root_url   # => 'http://www.example.com/'
  #   root_path  # => ''
  #
  # Note: when using +with_options+, the route is simply named after the
  # method you call on the block parameter rather than map.
  #
  #   # In routes.rb
  #   map.with_options :controller => 'blog' do |blog|
  #     blog.show    '',            :action  => 'list'
  #     blog.delete  'delete/:id',  :action  => 'delete',
  #     blog.edit    'edit/:id',    :action  => 'edit'
  #   end
  #
  #   # provides named routes for show, delete, and edit
  #   link_to @article.title, show_path(:id => @article.id) 
  #
  # == Pretty URLs
  #
  # Routes can generate pretty URLs. For example:
  #
  #  map.connect 'articles/:year/:month/:day',
  #              :controller => 'articles', 
  #              :action     => 'find_by_date',
  #              :year       => /\d{4}/,
  #              :month => /\d{1,2}/, 
  #              :day   => /\d{1,2}/
  #  
  #  # Using the route above, the url below maps to:
  #  # params = {:year => '2005', :month => '11', :day => '06'}
  #  # http://localhost:3000/articles/2005/11/06
  #
  # == Regular Expressions and parameters
  # You can specify a reqular expression to define a format for a parameter.
  #
  #  map.geocode 'geocode/:postalcode', :controller => 'geocode',
  #              :action => 'show', :postalcode => /\d{5}(-\d{4})?/
  #
  # or, more formally:
  #
  #   map.geocode 'geocode/:postalcode', :controller => 'geocode', 
  #               :action => 'show', :requirements => { :postalcode => /\d{5}(-\d{4})?/ }
  #
  # == Route globbing
  #
  # Specifying <tt>*[string]</tt> as part of a rule like :
  #
  #  map.connect '*path' , :controller => 'blog' , :action => 'unrecognized?'
  #
  # will glob all remaining parts of the route that were not recognized earlier. This idiom must appear at the end of the path. The globbed values are in <tt>params[:path]</tt> in this case.  
  #
  # == Reloading routes
  #
  # You can reload routes if you feel you must:
  #
  #  ActionController::Routing::Routes.reload
  #
  # This will clear all named routes and reload routes.rb
  #
  # == Testing Routes
  #
  # The two main methods for testing your routes:
  #
  # === +assert_routing+
  # 
  #  def test_movie_route_properly_splits
  #   opts = {:controller => "plugin", :action => "checkout", :id => "2"}
  #   assert_routing "plugin/checkout/2", opts
  #  end
  #  
  # +assert_routing+ lets you test whether or not the route properly resolves into options.
  #
  # === +assert_recognizes+
  #
  #  def test_route_has_options
  #   opts = {:controller => "plugin", :action => "show", :id => "12"}
  #   assert_recognizes opts, "/plugins/show/12" 
  #  end
  # 
  # Note the subtle difference between the two: +assert_routing+ tests that
  # an URL fits options while +assert_recognizes+ tests that an URL
  # breaks into parameters properly.
  #
  # In tests you can simply pass the URL or named route to +get+ or +post+.
  #
  #  def send_to_jail
  #    get '/jail'
  #    assert_response :success
  #    assert_template "jail/front"
  #  end
  #
  #  def goes_to_login
  #    get login_url
  #    #...
  #  end
  #
  module Routing
    SEPARATORS = %w( / . ? )

    HTTP_METHODS = [:get, :head, :post, :put, :delete]

    # The root paths which may contain controller files
    mattr_accessor :controller_paths
    self.controller_paths = []
    
    # A helper module to hold URL related helpers.
    module Helpers
      include PolymorphicRoutes
    end
    
    class << self
      def with_controllers(names)
        prior_controllers = @possible_controllers
        use_controllers! names
        yield
      ensure
        use_controllers! prior_controllers
      end

      def normalize_paths(paths)
        # do the hokey-pokey of path normalization...
        paths = paths.collect do |path|
          path = path.
            gsub("//", "/").           # replace double / chars with a single
            gsub("\\\\", "\\").        # replace double \ chars with a single
            gsub(%r{(.)[\\/]$}, '\1')  # drop final / or \ if path ends with it

          # eliminate .. paths where possible
          re = %r{\w+[/\\]\.\.[/\\]}
          path.gsub!(%r{\w+[/\\]\.\.[/\\]}, "") while path.match(re)
          path
        end

        # start with longest path, first
        paths = paths.uniq.sort_by { |path| - path.length }
      end

      def possible_controllers
        unless @possible_controllers
          @possible_controllers = []
        
          paths = controller_paths.select { |path| File.directory?(path) && path != "." }

          seen_paths = Hash.new {|h, k| h[k] = true; false}
          normalize_paths(paths).each do |load_path|
            Dir["#{load_path}/**/*_controller.rb"].collect do |path|
              next if seen_paths[path.gsub(%r{^\.[/\\]}, "")]
              
              controller_name = path[(load_path.length + 1)..-1]
              
              controller_name.gsub!(/_controller\.rb\Z/, '')
              @possible_controllers << controller_name
            end
          end

          # remove duplicates
          @possible_controllers.uniq!
        end
        @possible_controllers
      end

      def use_controllers!(controller_names)
        @possible_controllers = controller_names
      end

      def controller_relative_to(controller, previous)
        if controller.nil?           then previous
        elsif controller[0] == ?/    then controller[1..-1]
        elsif %r{^(.*)/} =~ previous then "#{$1}/#{controller}"
        else controller
        end     
      end     
    end
  
    class Route #:nodoc:
      attr_accessor :segments, :requirements, :conditions
      
      def initialize
        @segments = []
        @requirements = {}
        @conditions = {}
      end
  
      # Write and compile a +generate+ method for this Route.
      def write_generation
        # Build the main body of the generation
        body = "expired = false\n#{generation_extraction}\n#{generation_structure}"
    
        # If we have conditions that must be tested first, nest the body inside an if
        body = "if #{generation_requirements}\n#{body}\nend" if generation_requirements
        args = "options, hash, expire_on = {}"

        # Nest the body inside of a def block, and then compile it.
        raw_method = method_decl = "def generate_raw(#{args})\npath = begin\n#{body}\nend\n[path, hash]\nend"
        instance_eval method_decl, "generated code (#{__FILE__}:#{__LINE__})"

        # expire_on.keys == recall.keys; in other words, the keys in the expire_on hash
        # are the same as the keys that were recalled from the previous request. Thus,
        # we can use the expire_on.keys to determine which keys ought to be used to build
        # the query string. (Never use keys from the recalled request when building the
        # query string.)

        method_decl = "def generate(#{args})\npath, hash = generate_raw(options, hash, expire_on)\nappend_query_string(path, hash, extra_keys(options))\nend"
        instance_eval method_decl, "generated code (#{__FILE__}:#{__LINE__})"

        method_decl = "def generate_extras(#{args})\npath, hash = generate_raw(options, hash, expire_on)\n[path, extra_keys(options)]\nend"
        instance_eval method_decl, "generated code (#{__FILE__}:#{__LINE__})"
        raw_method
      end
  
      # Build several lines of code that extract values from the options hash. If any
      # of the values are missing or rejected then a return will be executed.
      def generation_extraction
        segments.collect do |segment|
          segment.extraction_code
        end.compact * "\n"
      end
  
      # Produce a condition expression that will check the requirements of this route
      # upon generation.
      def generation_requirements
        requirement_conditions = requirements.collect do |key, req|
          if req.is_a? Regexp
            value_regexp = Regexp.new "\\A#{req.source}\\Z"
            "hash[:#{key}] && #{value_regexp.inspect} =~ options[:#{key}]"
          else
            "hash[:#{key}] == #{req.inspect}"
          end
        end
        requirement_conditions * ' && ' unless requirement_conditions.empty?
      end
      def generation_structure
        segments.last.string_structure segments[0..-2]
      end
  
      # Write and compile a +recognize+ method for this Route.
      def write_recognition
        # Create an if structure to extract the params from a match if it occurs.
        body = "params = parameter_shell.dup\n#{recognition_extraction * "\n"}\nparams"
        body = "if #{recognition_conditions.join(" && ")}\n#{body}\nend"
    
        # Build the method declaration and compile it
        method_decl = "def recognize(path, env={})\n#{body}\nend"
        instance_eval method_decl, "generated code (#{__FILE__}:#{__LINE__})"
        method_decl
      end

      # Plugins may override this method to add other conditions, like checks on
      # host, subdomain, and so forth. Note that changes here only affect route
      # recognition, not generation.
      def recognition_conditions
        result = ["(match = #{Regexp.new(recognition_pattern).inspect}.match(path))"]
        result << "conditions[:method] === env[:method]" if conditions[:method]
        result
      end

      # Build the regular expression pattern that will match this route.
      def recognition_pattern(wrap = true)
        pattern = ''
        segments.reverse_each do |segment|
          pattern = segment.build_pattern pattern
        end
        wrap ? ("\\A" + pattern + "\\Z") : pattern
      end
      
      # Write the code to extract the parameters from a matched route.
      def recognition_extraction
        next_capture = 1
        extraction = segments.collect do |segment|
          x = segment.match_extraction(next_capture)
          next_capture += Regexp.new(segment.regexp_chunk).number_of_captures
          x
        end
        extraction.compact
      end
  
      # Write the real generation implementation and then resend the message.
      def generate(options, hash, expire_on = {})
        write_generation
        generate options, hash, expire_on
      end

      def generate_extras(options, hash, expire_on = {})
        write_generation
        generate_extras options, hash, expire_on
      end

      # Generate the query string with any extra keys in the hash and append
      # it to the given path, returning the new path.
      def append_query_string(path, hash, query_keys=nil)
        return nil unless path
        query_keys ||= extra_keys(hash)
        "#{path}#{build_query_string(hash, query_keys)}"
      end

      # Determine which keys in the given hash are "extra". Extra keys are
      # those that were not used to generate a particular route. The extra
      # keys also do not include those recalled from the prior request, nor
      # do they include any keys that were implied in the route (like a
      # :controller that is required, but not explicitly used in the text of
      # the route.)
      def extra_keys(hash, recall={})
        (hash || {}).keys.map { |k| k.to_sym } - (recall || {}).keys - significant_keys
      end

      # Build a query string from the keys of the given hash. If +only_keys+
      # is given (as an array), only the keys indicated will be used to build
      # the query string. The query string will correctly build array parameter
      # values.
      def build_query_string(hash, only_keys = nil)
        elements = []

        (only_keys || hash.keys).each do |key|
          if value = hash[key]
            elements << value.to_query(key)
          end
        end

        elements.empty? ? '' : "?#{elements.sort * '&'}"
      end

      # Write the real recognition implementation and then resend the message.
      def recognize(path, environment={})
        write_recognition
        recognize path, environment
      end
  
      # A route's parameter shell contains parameter values that are not in the
      # route's path, but should be placed in the recognized hash.
      # 
      # For example, +{:controller => 'pages', :action => 'show'} is the shell for the route:
      # 
      #   map.connect '/page/:id', :controller => 'pages', :action => 'show', :id => /\d+/
      # 
      def parameter_shell
        @parameter_shell ||= returning({}) do |shell|
          requirements.each do |key, requirement|
            shell[key] = requirement unless requirement.is_a? Regexp
          end
        end
      end
  
      # Return an array containing all the keys that are used in this route. This
      # includes keys that appear inside the path, and keys that have requirements
      # placed upon them.
      def significant_keys
        @significant_keys ||= returning [] do |sk|
          segments.each { |segment| sk << segment.key if segment.respond_to? :key }
          sk.concat requirements.keys
          sk.uniq!
        end
      end

      # Return a hash of key/value pairs representing the keys in the route that
      # have defaults, or which are specified by non-regexp requirements.
      def defaults
        @defaults ||= returning({}) do |hash|
          segments.each do |segment|
            next unless segment.respond_to? :default
            hash[segment.key] = segment.default unless segment.default.nil?
          end
          requirements.each do |key,req|
            next if Regexp === req || req.nil?
            hash[key] = req
          end
        end
      end

      def matches_controller_and_action?(controller, action)
        unless defined? @matching_prepared
          @controller_requirement = requirement_for(:controller)
          @action_requirement = requirement_for(:action)
          @matching_prepared = true
        end

        (@controller_requirement.nil? || @controller_requirement === controller) &&
        (@action_requirement.nil? || @action_requirement === action)
      end

      def to_s
        @to_s ||= begin
          segs = segments.inject("") { |str,s| str << s.to_s }
          "%-6s %-40s %s" % [(conditions[:method] || :any).to_s.upcase, segs, requirements.inspect]
        end
      end
  
    protected
      def requirement_for(key)
        return requirements[key] if requirements.key? key
        segments.each do |segment|
          return segment.regexp if segment.respond_to?(:key) && segment.key == key
        end
        nil
      end

    end

    class Segment #:nodoc:
      RESERVED_PCHAR = ':@&=+$,;'
      UNSAFE_PCHAR = Regexp.new("[^#{URI::REGEXP::PATTERN::UNRESERVED}#{RESERVED_PCHAR}]", false, 'N').freeze

      attr_accessor :is_optional
      alias_method :optional?, :is_optional

      def initialize
        self.is_optional = false
      end

      def extraction_code
        nil
      end
  
      # Continue generating string for the prior segments.
      def continue_string_structure(prior_segments)
        if prior_segments.empty?
          interpolation_statement(prior_segments)
        else
          new_priors = prior_segments[0..-2]
          prior_segments.last.string_structure(new_priors)
        end
      end

      def interpolation_chunk
        URI.escape(value, UNSAFE_PCHAR)
      end

      # Return a string interpolation statement for this segment and those before it.
      def interpolation_statement(prior_segments)
        chunks = prior_segments.collect { |s| s.interpolation_chunk }
        chunks << interpolation_chunk
        "\"#{chunks * ''}\"#{all_optionals_available_condition(prior_segments)}"
      end
  
      def string_structure(prior_segments)
        optional? ? continue_string_structure(prior_segments) : interpolation_statement(prior_segments)
      end
  
      # Return an if condition that is true if all the prior segments can be generated.
      # If there are no optional segments before this one, then nil is returned.
      def all_optionals_available_condition(prior_segments)
        optional_locals = prior_segments.collect { |s| s.local_name if s.optional? && s.respond_to?(:local_name) }.compact
        optional_locals.empty? ? nil : " if #{optional_locals * ' && '}"
      end
  
      # Recognition
  
      def match_extraction(next_capture)
        nil
      end
  
      # Warning
  
      # Returns true if this segment is optional? because of a default. If so, then
      # no warning will be emitted regarding this segment.
      def optionality_implied?
        false
      end
    end

    class StaticSegment < Segment #:nodoc:
      attr_accessor :value, :raw
      alias_method :raw?, :raw
  
      def initialize(value = nil)
        super()
        self.value = value
      end
  
      def interpolation_chunk
        raw? ? value : super
      end
  
      def regexp_chunk
        chunk = Regexp.escape(value)
        optional? ? Regexp.optionalize(chunk) : chunk
      end
  
      def build_pattern(pattern)
        escaped = Regexp.escape(value)
        if optional? && ! pattern.empty?
          "(?:#{Regexp.optionalize escaped}\\Z|#{escaped}#{Regexp.unoptionalize pattern})"
        elsif optional?
          Regexp.optionalize escaped
        else
          escaped + pattern
        end
      end
  
      def to_s
        value
      end
    end

    class DividerSegment < StaticSegment #:nodoc:
      def initialize(value = nil)
        super(value)
        self.raw = true
        self.is_optional = true
      end
  
      def optionality_implied?
        true
      end
    end

    class DynamicSegment < Segment #:nodoc:
      attr_accessor :key, :default, :regexp
  
      def initialize(key = nil, options = {})
        super()
        self.key = key
        self.default = options[:default] if options.key? :default
        self.is_optional = true if options[:optional] || options.key?(:default)
      end
  
      def to_s
        ":#{key}"
      end
  
      # The local variable name that the value of this segment will be extracted to.
      def local_name
        "#{key}_value"
      end
  
      def extract_value
        "#{local_name} = hash[:#{key}] && hash[:#{key}].to_param #{"|| #{default.inspect}" if default}"
      end
      def value_check
        if default # Then we know it won't be nil
          "#{value_regexp.inspect} =~ #{local_name}" if regexp
        elsif optional?
          # If we have a regexp check that the value is not given, or that it matches.
          # If we have no regexp, return nil since we do not require a condition.
          "#{local_name}.nil? || #{value_regexp.inspect} =~ #{local_name}" if regexp
        else # Then it must be present, and if we have a regexp, it must match too.
          "#{local_name} #{"&& #{value_regexp.inspect} =~ #{local_name}" if regexp}"
        end
      end
      def expiry_statement
        "expired, hash = true, options if !expired && expire_on[:#{key}]"
      end
  
      def extraction_code
        s = extract_value
        vc = value_check
        s << "\nreturn [nil,nil] unless #{vc}" if vc
        s << "\n#{expiry_statement}"
      end
  
      def interpolation_chunk
        "\#{URI.escape(#{local_name}.to_s, ActionController::Routing::Segment::UNSAFE_PCHAR)}"
      end
  
      def string_structure(prior_segments)
        if optional? # We have a conditional to do...
          # If we should not appear in the url, just write the code for the prior
          # segments. This occurs if our value is the default value, or, if we are
          # optional, if we have nil as our value.
          "if #{local_name} == #{default.inspect}\n" + 
            continue_string_structure(prior_segments) + 
          "\nelse\n" + # Otherwise, write the code up to here
            "#{interpolation_statement(prior_segments)}\nend"
        else
          interpolation_statement(prior_segments)
        end
      end
  
      def value_regexp
        Regexp.new "\\A#{regexp.source}\\Z" if regexp
      end
      def regexp_chunk
        regexp ? "(#{regexp.source})" : "([^#{Routing::SEPARATORS.join}]+)"
      end
  
      def build_pattern(pattern)
        chunk = regexp_chunk
        chunk = "(#{chunk})" if Regexp.new(chunk).number_of_captures == 0
        pattern = "#{chunk}#{pattern}"
        optional? ? Regexp.optionalize(pattern) : pattern
      end
      def match_extraction(next_capture)
        # All non code-related keys (such as :id, :slug) are URI-unescaped as
        # path parameters.
        default_value = default ? default.inspect : nil
        %[
          value = if (m = match[#{next_capture}])
            URI.unescape(m)
          else
            #{default_value}
          end
          params[:#{key}] = value if value
        ]
      end
  
      def optionality_implied?
        [:action, :id].include? key
      end
  
    end

    class ControllerSegment < DynamicSegment #:nodoc:
      def regexp_chunk
        possible_names = Routing.possible_controllers.collect { |name| Regexp.escape name }
        "(?i-:(#{(regexp || Regexp.union(*possible_names)).source}))"
      end

      # Don't URI.escape the controller name since it may contain slashes.
      def interpolation_chunk
        "\#{#{local_name}.to_s}"
      end

      # Make sure controller names like Admin/Content are correctly normalized to
      # admin/content
      def extract_value
        "#{local_name} = (hash[:#{key}] #{"|| #{default.inspect}" if default}).downcase"
      end

      def match_extraction(next_capture)
        if default
          "params[:#{key}] = match[#{next_capture}] ? match[#{next_capture}].downcase : '#{default}'"
        else
          "params[:#{key}] = match[#{next_capture}].downcase if match[#{next_capture}]"
        end
      end
    end

    class PathSegment < DynamicSegment #:nodoc:
      RESERVED_PCHAR = "#{Segment::RESERVED_PCHAR}/"
      UNSAFE_PCHAR = Regexp.new("[^#{URI::REGEXP::PATTERN::UNRESERVED}#{RESERVED_PCHAR}]", false, 'N').freeze

      def interpolation_chunk
        "\#{URI.escape(#{local_name}.to_s, ActionController::Routing::PathSegment::UNSAFE_PCHAR)}"
      end

      def default
        ''
      end

      def default=(path)
        raise RoutingError, "paths cannot have non-empty default values" unless path.blank?
      end

      def match_extraction(next_capture)
        "params[:#{key}] = PathSegment::Result.new_escaped((match[#{next_capture}]#{" || " + default.inspect if default}).split('/'))#{" if match[" + next_capture + "]" if !default}"
      end

      def regexp_chunk
        regexp || "(.*)"
      end

      class Result < ::Array #:nodoc:
        def to_s() join '/' end 
        def self.new_escaped(strings)
          new strings.collect {|str| URI.unescape str}
        end     
      end     
    end

    class RouteBuilder #:nodoc:
      attr_accessor :separators, :optional_separators
  
      def initialize
        self.separators = Routing::SEPARATORS
        self.optional_separators = %w( / )
      end
  
      def separator_pattern(inverted = false)
        "[#{'^' if inverted}#{Regexp.escape(separators.join)}]"
      end
  
      def interval_regexp
        Regexp.new "(.*?)(#{separators.source}|$)"
      end
  
      # Accepts a "route path" (a string defining a route), and returns the array
      # of segments that corresponds to it. Note that the segment array is only
      # partially initialized--the defaults and requirements, for instance, need
      # to be set separately, via the #assign_route_options method, and the
      # #optional? method for each segment will not be reliable until after
      # #assign_route_options is called, as well.
      def segments_for_route_path(path)
        rest, segments = path, []
    
        until rest.empty?
          segment, rest = segment_for rest
          segments << segment
        end
        segments
      end

      # A factory method that returns a new segment instance appropriate for the
      # format of the given string.
      def segment_for(string)
        segment = case string
          when /\A:(\w+)/
            key = $1.to_sym
            case key
              when :controller then ControllerSegment.new(key)
              else DynamicSegment.new key
            end
          when /\A\*(\w+)/ then PathSegment.new($1.to_sym, :optional => true)
          when /\A\?(.*?)\?/
            returning segment = StaticSegment.new($1) do
              segment.is_optional = true
            end
          when /\A(#{separator_pattern(:inverted)}+)/ then StaticSegment.new($1)
          when Regexp.new(separator_pattern) then
            returning segment = DividerSegment.new($&) do
              segment.is_optional = (optional_separators.include? $&)
            end
        end
        [segment, $~.post_match]
      end
  
      # Split the given hash of options into requirement and default hashes. The
      # segments are passed alongside in order to distinguish between default values
      # and requirements.
      def divide_route_options(segments, options)
        options = options.dup
        
        if options[:namespace]
          options[:controller] = "#{options[:path_prefix]}/#{options[:controller]}"
          options.delete(:path_prefix)
          options.delete(:name_prefix)
          options.delete(:namespace)
        end        
                
        requirements = (options.delete(:requirements) || {}).dup
        defaults     = (options.delete(:defaults)     || {}).dup
        conditions   = (options.delete(:conditions)   || {}).dup

        path_keys = segments.collect { |segment| segment.key if segment.respond_to?(:key) }.compact
        options.each do |key, value|
          hash = (path_keys.include?(key) && ! value.is_a?(Regexp)) ? defaults : requirements
          hash[key] = value
        end
            
        [defaults, requirements, conditions]
      end
      
      # Takes a hash of defaults and a hash of requirements, and assigns them to
      # the segments. Any unused requirements (which do not correspond to a segment)
      # are returned as a hash.
      def assign_route_options(segments, defaults, requirements)
        route_requirements = {} # Requirements that do not belong to a segment
        
        segment_named = Proc.new do |key|
          segments.detect { |segment| segment.key == key if segment.respond_to?(:key) }
        end
        
        requirements.each do |key, requirement|
          segment = segment_named[key]
          if segment
            raise TypeError, "#{key}: requirements on a path segment must be regular expressions" unless requirement.is_a?(Regexp)
            if requirement.source =~ %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}
              raise ArgumentError, "Regexp anchor characters are not allowed in routing requirements: #{requirement.inspect}"
            end
            segment.regexp = requirement
          else
            route_requirements[key] = requirement
          end
        end
        
        defaults.each do |key, default|
          segment = segment_named[key]
          raise ArgumentError, "#{key}: No matching segment exists; cannot assign default" unless segment
          segment.is_optional = true
          segment.default = default.to_param if default
        end
        
        assign_default_route_options(segments)
        ensure_required_segments(segments)
        route_requirements
      end
      
      # Assign default options, such as 'index' as a default for :action. This
      # method must be run *after* user supplied requirements and defaults have
      # been applied to the segments.
      def assign_default_route_options(segments)
        segments.each do |segment|
          next unless segment.is_a? DynamicSegment
          case segment.key
            when :action
              if segment.regexp.nil? || segment.regexp.match('index').to_s == 'index'
                segment.default ||= 'index'
                segment.is_optional = true
              end
            when :id
              if segment.default.nil? && segment.regexp.nil? || segment.regexp =~ ''
                segment.is_optional = true
              end
          end
        end
      end
      
      # Makes sure that there are no optional segments that precede a required
      # segment. If any are found that precede a required segment, they are
      # made required.
      def ensure_required_segments(segments)
        allow_optional = true
        segments.reverse_each do |segment|
          allow_optional &&= segment.optional?
          if !allow_optional && segment.optional?
            unless segment.optionality_implied?
              warn "Route segment \"#{segment.to_s}\" cannot be optional because it precedes a required segment. This segment will be required."
            end
            segment.is_optional = false
          elsif allow_optional & segment.respond_to?(:default) && segment.default
            # if a segment has a default, then it is optional
            segment.is_optional = true
          end
        end
      end
      
      # Construct and return a route with the given path and options.
      def build(path, options)
        # Wrap the path with slashes
        path = "/#{path}" unless path[0] == ?/
        path = "#{path}/" unless path[-1] == ?/    
        
        path = "/#{options[:path_prefix]}#{path}" if options[:path_prefix]
    
        segments = segments_for_route_path(path)
        defaults, requirements, conditions = divide_route_options(segments, options)
        requirements = assign_route_options(segments, defaults, requirements)

        route = Route.new
        route.segments = segments
        route.requirements = requirements
        route.conditions = conditions

        if !route.significant_keys.include?(:action) && !route.requirements[:action]
          route.requirements[:action] = "index"
          route.significant_keys << :action
        end

        if !route.significant_keys.include?(:controller)
          raise ArgumentError, "Illegal route: the :controller must be specified!"
        end

        route
      end
    end

    class RouteSet #:nodoc:
      # Mapper instances are used to build routes. The object passed to the draw
      # block in config/routes.rb is a Mapper instance.
      # 
      # Mapper instances have relatively few instance methods, in order to avoid
      # clashes with named routes.
      class Mapper #:nodoc:
        def initialize(set)
          @set = set
        end
    
        # Create an unnamed route with the provided +path+ and +options+. See 
        # SomeHelpfulUrl for an introduction to routes.
        def connect(path, options = {})
          @set.add_route(path, options)
        end

        # Creates a named route called "root" for matching the root level request.
        def root(options = {})
          named_route("root", '', options)
        end

        def named_route(name, path, options = {})
          @set.add_named_route(name, path, options)
        end
        
        # Enables the use of resources in a module by setting the name_prefix, path_prefix, and namespace for the model.
        # Example:
        #
        #   map.namespace(:admin) do |admin|
        #     admin.resources :products,
        #       :has_many => [ :tags, :images, :variants ]
        #   end
        #
        # This will create admin_products_url pointing to "admin/products", which will look for an Admin::ProductsController.
        # It'll also create admin_product_tags_url pointing to "admin/products/#{product_id}/tags", which will look for
        # Admin::TagsController.
        def namespace(name, options = {}, &block)
          if options[:namespace]
            with_options({:path_prefix => "#{options.delete(:path_prefix)}/#{name}", :name_prefix => "#{options.delete(:name_prefix)}#{name}_", :namespace => "#{options.delete(:namespace)}#{name}/" }.merge(options), &block)
          else
            with_options({:path_prefix => name, :name_prefix => "#{name}_", :namespace => "#{name}/" }.merge(options), &block)
          end
        end
        

        def method_missing(route_name, *args, &proc)
          super unless args.length >= 1 && proc.nil?
          @set.add_named_route(route_name, *args)
        end
      end

      # A NamedRouteCollection instance is a collection of named routes, and also
      # maintains an anonymous module that can be used to install helpers for the
      # named routes.
      class NamedRouteCollection #:nodoc:
        include Enumerable

        attr_reader :routes, :helpers

        def initialize
          clear!
        end

        def clear!
          @routes = {}
          @helpers = []
          
          @module ||= Module.new
          @module.instance_methods.each do |selector|
            @module.send :remove_method, selector
          end
        end

        def add(name, route)
          routes[name.to_sym] = route
          define_named_route_methods(name, route)
        end

        def get(name)
          routes[name.to_sym]
        end

        alias []=   add
        alias []    get
        alias clear clear!

        def each
          routes.each { |name, route| yield name, route }
          self
        end

        def names
          routes.keys
        end

        def length
          routes.length
        end

        def install(destinations = [ActionController::Base, ActionView::Base])
          Array(destinations).each { |dest| dest.send :include, @module }
        end

        private
          def url_helper_name(name, kind = :url)
            :"#{name}_#{kind}"
          end

          def hash_access_name(name, kind = :url)
            :"hash_for_#{name}_#{kind}"
          end

          def define_named_route_methods(name, route)
            {:url => {:only_path => false}, :path => {:only_path => true}}.each do |kind, opts|
              hash = route.defaults.merge(:use_route => name).merge(opts)
              define_hash_access route, name, kind, hash
              define_url_helper route, name, kind, hash
            end
          end
          
          def define_hash_access(route, name, kind, options)
            selector = hash_access_name(name, kind)
            @module.send :module_eval, <<-end_eval # We use module_eval to avoid leaks
              def #{selector}(options = nil)
                options ? #{options.inspect}.merge(options) : #{options.inspect}
              end
            end_eval
            @module.send(:protected, selector)
            helpers << selector
          end
          
          def define_url_helper(route, name, kind, options)
            selector = url_helper_name(name, kind)
            
            # The segment keys used for positional paramters
            segment_keys = route.segments.collect do |segment|
              segment.key if segment.respond_to? :key
            end.compact
            hash_access_method = hash_access_name(name, kind)
            
            @module.send :module_eval, <<-end_eval # We use module_eval to avoid leaks
              def #{selector}(*args)
                opts = if args.empty? || Hash === args.first
                  args.first || {}
                else
                  # allow ordered parameters to be associated with corresponding
                  # dynamic segments, so you can do
                  #
                  #   foo_url(bar, baz, bang)
                  #
                  # instead of
                  #
                  #   foo_url(:bar => bar, :baz => baz, :bang => bang)
                  args.zip(#{segment_keys.inspect}).inject({}) do |h, (v, k)|
                    h[k] = v
                    h
                  end
                end
                
                url_for(#{hash_access_method}(opts))
              end
            end_eval
            @module.send(:protected, selector)
            helpers << selector
          end
          
      end
  
      attr_accessor :routes, :named_routes
  
      def initialize
        self.routes = []
        self.named_routes = NamedRouteCollection.new
      end

      # Subclasses and plugins may override this method to specify a different
      # RouteBuilder instance, so that other route DSL's can be created.
      def builder
        @builder ||= RouteBuilder.new
      end

      def draw
        clear!
        yield Mapper.new(self)
        install_helpers
      end
      
      def clear!
        routes.clear
        named_routes.clear
        @combined_regexp = nil
        @routes_by_controller = nil
      end
      
      def install_helpers(destinations = [ActionController::Base, ActionView::Base])
        Array(destinations).each { |d| d.send :include, Helpers }
        named_routes.install(destinations)
      end

      def empty?
        routes.empty?
      end
  
      def load!
        Routing.use_controllers! nil # Clear the controller cache so we may discover new ones
        clear!
        load_routes!
        install_helpers
      end

      alias reload load!
      
      def load_routes!
        if defined?(RAILS_ROOT) && defined?(::ActionController::Routing::Routes) && self == ::ActionController::Routing::Routes
          load File.join("#{RAILS_ROOT}/config/routes.rb")
        else
          add_route ":controller/:action/:id"
        end
      end
  
      def add_route(path, options = {})
        route = builder.build(path, options)
        routes << route
        route
      end
  
      def add_named_route(name, path, options = {})
        name = options[:name_prefix] + name.to_s if options[:name_prefix]
        named_routes[name.to_sym] = add_route(path, options)
      end
  
      def options_as_params(options)
        # If an explicit :controller was given, always make :action explicit
        # too, so that action expiry works as expected for things like
        #
        #   generate({:controller => 'content'}, {:controller => 'content', :action => 'show'})
        #
        # (the above is from the unit tests). In the above case, because the
        # controller was explicitly given, but no action, the action is implied to
        # be "index", not the recalled action of "show".
        #
        # great fun, eh?

        options_as_params = options.clone
        options_as_params[:action] ||= 'index' if options[:controller]
        options_as_params[:action] = options_as_params[:action].to_s if options_as_params[:action]
        options_as_params
      end
  
      def build_expiry(options, recall)
        recall.inject({}) do |expiry, (key, recalled_value)|
          expiry[key] = (options.key?(key) && options[key].to_param != recalled_value.to_param)
          expiry
        end
      end

      # Generate the path indicated by the arguments, and return an array of
      # the keys that were not used to generate it.
      def extra_keys(options, recall={})
        generate_extras(options, recall).last
      end

      def generate_extras(options, recall={})
        generate(options, recall, :generate_extras)
      end

      def generate(options, recall = {}, method=:generate)
        named_route_name = options.delete(:use_route)
        generate_all = options.delete(:generate_all)
        if named_route_name
          named_route = named_routes[named_route_name]
          options = named_route.parameter_shell.merge(options)
        end

        options = options_as_params(options)
        expire_on = build_expiry(options, recall)

        # if the controller has changed, make sure it changes relative to the
        # current controller module, if any. In other words, if we're currently
        # on admin/get, and the new controller is 'set', the new controller
        # should really be admin/set.
        if !named_route && expire_on[:controller] && options[:controller] && options[:controller][0] != ?/
          old_parts = recall[:controller].split('/')
          new_parts = options[:controller].split('/')
          parts = old_parts[0..-(new_parts.length + 1)] + new_parts
          options[:controller] = parts.join('/')
        end

        # drop the leading '/' on the controller name
        options[:controller] = options[:controller][1..-1] if options[:controller] && options[:controller][0] == ?/
        merged = recall.merge(options)

        if named_route
          path = named_route.generate(options, merged, expire_on)
          if path.nil? 
            raise_named_route_error(options, named_route, named_route_name)
          else
            return path
          end
        else
          merged[:action] ||= 'index'
          options[:action] ||= 'index'
  
          controller = merged[:controller]
          action = merged[:action]

          raise RoutingError, "Need controller and action!" unless controller && action
          
          if generate_all
            # Used by caching to expire all paths for a resource
            return routes.collect do |route|
              route.send(method, options, merged, expire_on)
            end.compact
          end
          
          # don't use the recalled keys when determining which routes to check
          routes = routes_by_controller[controller][action][options.keys.sort_by { |x| x.object_id }]

          routes.each do |route|
            results = route.send(method, options, merged, expire_on)
            return results if results && (!results.is_a?(Array) || results.first)
          end
        end
    
        raise RoutingError, "No route matches #{options.inspect}"
      end
      
      # try to give a helpful error message when named route generation fails
      def raise_named_route_error(options, named_route, named_route_name)
        diff = named_route.requirements.diff(options)
        unless diff.empty?
          raise RoutingError, "#{named_route_name}_url failed to generate from #{options.inspect}, expected: #{named_route.requirements.inspect}, diff: #{named_route.requirements.diff(options).inspect}"
        else
          required_segments = named_route.segments.select {|seg| (!seg.optional?) && (!seg.is_a?(DividerSegment)) }
          required_keys_or_values = required_segments.map { |seg| seg.key rescue seg.value } # we want either the key or the value from the segment
          raise RoutingError, "#{named_route_name}_url failed to generate from #{options.inspect} - you may have ambiguous routes, or you may need to supply additional parameters for this route.  content_url has the following required parameters: #{required_keys_or_values.inspect} - are they all satisfied?"
        end
      end
  
      def recognize(request)
        params = recognize_path(request.path, extract_request_environment(request))
        request.path_parameters = params.with_indifferent_access
        "#{params[:controller].camelize}Controller".constantize
      end
  
      def recognize_path(path, environment={})
        routes.each do |route|
          result = route.recognize(path, environment) and return result
        end

        allows = HTTP_METHODS.select { |verb| routes.find { |r| r.recognize(path, :method => verb) } }

        if environment[:method] && !HTTP_METHODS.include?(environment[:method])
          raise NotImplemented.new(*allows)
        elsif !allows.empty?
          raise MethodNotAllowed.new(*allows)
        else
          raise RoutingError, "No route matches #{path.inspect} with #{environment.inspect}"
        end
      end
  
      def routes_by_controller
        @routes_by_controller ||= Hash.new do |controller_hash, controller|
          controller_hash[controller] = Hash.new do |action_hash, action|
            action_hash[action] = Hash.new do |key_hash, keys|
              key_hash[keys] = routes_for_controller_and_action_and_keys(controller, action, keys)
            end
          end
        end
      end
  
      def routes_for(options, merged, expire_on)
        raise "Need controller and action!" unless controller && action
        controller = merged[:controller]
        merged = options if expire_on[:controller]
        action = merged[:action] || 'index'
    
        routes_by_controller[controller][action][merged.keys]
      end
  
      def routes_for_controller_and_action(controller, action)
        selected = routes.select do |route|
          route.matches_controller_and_action? controller, action
        end
        (selected.length == routes.length) ? routes : selected
      end
  
      def routes_for_controller_and_action_and_keys(controller, action, keys)
        selected = routes.select do |route|
          route.matches_controller_and_action? controller, action
        end
        selected.sort_by do |route|
          (keys - route.significant_keys).length
        end
      end

      # Subclasses and plugins may override this method to extract further attributes
      # from the request, for use by route conditions and such.
      def extract_request_environment(request)
        { :method => request.method }
      end
    end

    Routes = RouteSet.new
  end
end

