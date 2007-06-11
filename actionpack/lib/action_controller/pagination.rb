module ActionController
  # === Action Pack pagination for Active Record collections
  #
  # DEPRECATION WARNING: Pagination will be moved to a plugin in Rails 2.0.
  # Install the classic_pagination plugin for forward compatibility:
  #   script/plugin install svn://errtheblog.com/svn/plugins/classic_pagination
  #
  # The Pagination module aids in the process of paging large collections of
  # Active Record objects. It offers macro-style automatic fetching of your
  # model for multiple views, or explicit fetching for single actions. And if
  # the magic isn't flexible enough for your needs, you can create your own
  # paginators with a minimal amount of code.
  #
  # The Pagination module can handle as much or as little as you wish. In the
  # controller, have it automatically query your model for pagination; or,
  # if you prefer, create Paginator objects yourself.
  #
  # Pagination is included automatically for all controllers.
  #
  # For help rendering pagination links, see 
  # ActionView::Helpers::PaginationHelper.
  #
  # ==== Automatic pagination for every action in a controller
  #
  #   class PersonController < ApplicationController   
  #     model :person
  #
  #     paginate :people, :order => 'last_name, first_name',
  #              :per_page => 20
  #     
  #     # ...
  #   end
  #
  # Each action in this controller now has access to a <tt>@people</tt>
  # instance variable, which is an ordered collection of model objects for the
  # current page (at most 20, sorted by last name and first name), and a 
  # <tt>@person_pages</tt> Paginator instance. The current page is determined
  # by the <tt>params[:page]</tt> variable.
  #
  # ==== Pagination for a single action
  #
  #   def list
  #     @person_pages, @people =
  #       paginate :people, :order => 'last_name, first_name'
  #   end
  #
  # Like the previous example, but explicitly creates <tt>@person_pages</tt>
  # and <tt>@people</tt> for a single action, and uses the default of 10 items
  # per page.
  #
  # ==== Custom/"classic" pagination 
  #
  #   def list
  #     @person_pages = Paginator.new self, Person.count, 10, params[:page]
  #     @people = Person.find :all, :order => 'last_name, first_name', 
  #                           :limit  =>  @person_pages.items_per_page,
  #                           :offset =>  @person_pages.current.offset
  #   end
  # 
  # Explicitly creates the paginator from the previous example and uses 
  # Paginator#to_sql to retrieve <tt>@people</tt> from the model.
  #
  module Pagination
    unless const_defined?(:OPTIONS)
      # A hash holding options for controllers using macro-style pagination
      OPTIONS = Hash.new
  
      # The default options for pagination
      DEFAULT_OPTIONS = {
        :class_name => nil,
        :singular_name => nil,
        :per_page   => 10,
        :conditions => nil,
        :order_by   => nil,
        :order      => nil,
        :join       => nil,
        :joins      => nil,
        :count      => nil,
        :include    => nil,
        :select     => nil,
        :parameter  => 'page'
      }
    end
      
    def self.included(base) #:nodoc:
      super
      base.extend(ClassMethods)
    end
  
    def self.validate_options!(collection_id, options, in_action) #:nodoc:
      options.merge!(DEFAULT_OPTIONS) {|key, old, new| old}

      valid_options = DEFAULT_OPTIONS.keys
      valid_options << :actions unless in_action
    
      unknown_option_keys = options.keys - valid_options
      raise ActionController::ActionControllerError,
            "Unknown options: #{unknown_option_keys.join(', ')}" unless
              unknown_option_keys.empty?

      options[:singular_name] ||= Inflector.singularize(collection_id.to_s)
      options[:class_name]  ||= Inflector.camelize(options[:singular_name])
    end

    # Returns a paginator and a collection of Active Record model instances
    # for the paginator's current page. This is designed to be used in a
    # single action; to automatically paginate multiple actions, consider
    # ClassMethods#paginate.
    #
    # +options+ are:
    # <tt>:singular_name</tt>:: the singular name to use, if it can't be inferred by singularizing the collection name
    # <tt>:class_name</tt>:: the class name to use, if it can't be inferred by
    #                        camelizing the singular name
    # <tt>:per_page</tt>::   the maximum number of items to include in a 
    #                        single page. Defaults to 10
    # <tt>:conditions</tt>:: optional conditions passed to Model.find(:all, *params) and
    #                        Model.count
    # <tt>:order</tt>::      optional order parameter passed to Model.find(:all, *params)
    # <tt>:order_by</tt>::   (deprecated, used :order) optional order parameter passed to Model.find(:all, *params)
    # <tt>:joins</tt>::      optional joins parameter passed to Model.find(:all, *params)
    #                        and Model.count
    # <tt>:join</tt>::       (deprecated, used :joins or :include) optional join parameter passed to Model.find(:all, *params)
    #                        and Model.count
    # <tt>:include</tt>::    optional eager loading parameter passed to Model.find(:all, *params)
    #                        and Model.count
    # <tt>:select</tt>::     :select parameter passed to Model.find(:all, *params)
    #
    # <tt>:count</tt>::      parameter passed as :select option to Model.count(*params)
    #
    def paginate(collection_id, options={})
      Pagination.validate_options!(collection_id, options, true)
      paginator_and_collection_for(collection_id, options)
    end

    deprecate :paginate => 'Pagination is moving to a plugin in Rails 2.0: script/plugin install svn://errtheblog.com/svn/plugins/classic_pagination'

    # These methods become class methods on any controller 
    module ClassMethods
      # Creates a +before_filter+ which automatically paginates an Active
      # Record model for all actions in a controller (or certain actions if
      # specified with the <tt>:actions</tt> option).
      #
      # +options+ are the same as PaginationHelper#paginate, with the addition 
      # of:
      # <tt>:actions</tt>:: an array of actions for which the pagination is
      #                     active. Defaults to +nil+ (i.e., every action)
      def paginate(collection_id, options={})
        Pagination.validate_options!(collection_id, options, false)
        module_eval do
          before_filter :create_paginators_and_retrieve_collections
          OPTIONS[self] ||= Hash.new
          OPTIONS[self][collection_id] = options
        end
      end

      deprecate :paginate => 'Pagination is moving to a plugin in Rails 2.0: script/plugin install svn://errtheblog.com/svn/plugins/classic_pagination'
    end

    def create_paginators_and_retrieve_collections #:nodoc:
      Pagination::OPTIONS[self.class].each do |collection_id, options|
        next unless options[:actions].include? action_name if
          options[:actions]

        paginator, collection = 
          paginator_and_collection_for(collection_id, options)

        paginator_name = "@#{options[:singular_name]}_pages"
        self.instance_variable_set(paginator_name, paginator)

        collection_name = "@#{collection_id.to_s}"
        self.instance_variable_set(collection_name, collection)     
      end
    end
  
    # Returns the total number of items in the collection to be paginated for
    # the +model+ and given +conditions+. Override this method to implement a
    # custom counter.
    def count_collection_for_pagination(model, options)
      model.count(:conditions => options[:conditions],
                  :joins => options[:join] || options[:joins],
                  :include => options[:include],
                  :select => options[:count])
    end
    
    # Returns a collection of items for the given +model+ and +options[conditions]+,
    # ordered by +options[order]+, for the current page in the given +paginator+.
    # Override this method to implement a custom finder.
    def find_collection_for_pagination(model, options, paginator)
      model.find(:all, :conditions => options[:conditions],
                 :order => options[:order_by] || options[:order],
                 :joins => options[:join] || options[:joins], :include => options[:include],
                 :select => options[:select], :limit => options[:per_page],
                 :offset => paginator.current.offset)
    end
  
    protected :create_paginators_and_retrieve_collections,
              :count_collection_for_pagination,
              :find_collection_for_pagination

    def paginator_and_collection_for(collection_id, options) #:nodoc:
      klass = options[:class_name].constantize
      page  = params[options[:parameter]]
      count = count_collection_for_pagination(klass, options)
      paginator = Paginator.new(self, count, options[:per_page], page)
      collection = find_collection_for_pagination(klass, options, paginator)
    
      return paginator, collection 
    end
      
    private :paginator_and_collection_for

    # A class representing a paginator for an Active Record collection.
    class Paginator
      include Enumerable

      # Creates a new Paginator on the given +controller+ for a set of items
      # of size +item_count+ and having +items_per_page+ items per page.
      # Raises ArgumentError if items_per_page is out of bounds (i.e., less
      # than or equal to zero). The page CGI parameter for links defaults to
      # "page" and can be overridden with +page_parameter+.
      def initialize(controller, item_count, items_per_page, current_page=1)
        raise ArgumentError, 'must have at least one item per page' if
          items_per_page <= 0

        @controller = controller
        @item_count = item_count || 0
        @items_per_page = items_per_page
        @pages = {}
        
        self.current_page = current_page
      end
      attr_reader :controller, :item_count, :items_per_page
      
      # Sets the current page number of this paginator. If +page+ is a Page
      # object, its +number+ attribute is used as the value; if the page does 
      # not belong to this Paginator, an ArgumentError is raised.
      def current_page=(page)
        if page.is_a? Page
          raise ArgumentError, 'Page/Paginator mismatch' unless
            page.paginator == self
        end
        page = page.to_i
        @current_page_number = has_page_number?(page) ? page : 1
      end

      # Returns a Page object representing this paginator's current page.
      def current_page
        @current_page ||= self[@current_page_number]
      end
      alias current :current_page

      # Returns a new Page representing the first page in this paginator.
      def first_page
        @first_page ||= self[1]
      end
      alias first :first_page

      # Returns a new Page representing the last page in this paginator.
      def last_page
        @last_page ||= self[page_count] 
      end
      alias last :last_page

      # Returns the number of pages in this paginator.
      def page_count
        @page_count ||= @item_count.zero? ? 1 :
                          (q,r=@item_count.divmod(@items_per_page); r==0? q : q+1)
      end

      alias length :page_count

      # Returns true if this paginator contains the page of index +number+.
      def has_page_number?(number)
        number >= 1 and number <= page_count
      end

      # Returns a new Page representing the page with the given index
      # +number+.
      def [](number)
        @pages[number] ||= Page.new(self, number)
      end

      # Successively yields all the paginator's pages to the given block.
      def each(&block)
        page_count.times do |n|
          yield self[n+1]
        end
      end

      # A class representing a single page in a paginator.
      class Page
        include Comparable

        # Creates a new Page for the given +paginator+ with the index
        # +number+. If +number+ is not in the range of valid page numbers or
        # is not a number at all, it defaults to 1.
        def initialize(paginator, number)
          @paginator = paginator
          @number = number.to_i
          @number = 1 unless @paginator.has_page_number? @number
        end
        attr_reader :paginator, :number
        alias to_i :number

        # Compares two Page objects and returns true when they represent the 
        # same page (i.e., their paginators are the same and they have the
        # same page number).
        def ==(page)
          return false if page.nil?
          @paginator == page.paginator and 
            @number == page.number
        end

        # Compares two Page objects and returns -1 if the left-hand page comes
        # before the right-hand page, 0 if the pages are equal, and 1 if the
        # left-hand page comes after the right-hand page. Raises ArgumentError
        # if the pages do not belong to the same Paginator object.
        def <=>(page)
          raise ArgumentError unless @paginator == page.paginator
          @number <=> page.number
        end

        # Returns the item offset for the first item in this page.
        def offset
          @paginator.items_per_page * (@number - 1)
        end
        
        # Returns the number of the first item displayed.
        def first_item
          offset + 1
        end
        
        # Returns the number of the last item displayed.
        def last_item
          [@paginator.items_per_page * @number, @paginator.item_count].min
        end

        # Returns true if this page is the first page in the paginator.
        def first?
          self == @paginator.first
        end

        # Returns true if this page is the last page in the paginator.
        def last?
          self == @paginator.last
        end

        # Returns a new Page object representing the page just before this
        # page, or nil if this is the first page.
        def previous
          if first? then nil else @paginator[@number - 1] end
        end

        # Returns a new Page object representing the page just after this
        # page, or nil if this is the last page.
        def next
          if last? then nil else @paginator[@number + 1] end
        end

        # Returns a new Window object for this page with the specified 
        # +padding+.
        def window(padding=2)
          Window.new(self, padding)
        end

        # Returns the limit/offset array for this page.
        def to_sql
          [@paginator.items_per_page, offset]
        end
        
        def to_param #:nodoc:
          @number.to_s
        end
      end

      # A class for representing ranges around a given page.
      class Window
        # Creates a new Window object for the given +page+ with the specified
        # +padding+.
        def initialize(page, padding=2)
          @paginator = page.paginator
          @page = page
          self.padding = padding
        end
        attr_reader :paginator, :page

        # Sets the window's padding (the number of pages on either side of the
        # window page).
        def padding=(padding)
          @padding = padding < 0 ? 0 : padding
          # Find the beginning and end pages of the window
          @first = @paginator.has_page_number?(@page.number - @padding) ?
            @paginator[@page.number - @padding] : @paginator.first
          @last =  @paginator.has_page_number?(@page.number + @padding) ?
            @paginator[@page.number + @padding] : @paginator.last
        end
        attr_reader :padding, :first, :last

        # Returns an array of Page objects in the current window.
        def pages
          (@first.number..@last.number).to_a.collect! {|n| @paginator[n]}
        end
        alias to_a :pages
      end
    end

  end
end
