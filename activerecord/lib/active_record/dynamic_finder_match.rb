module ActiveRecord

  # = Active Record Dynamic Finder Match
  # 
  # Provides dynamic attribute-based finders such as <tt>find_by_country</tt> 
  # if, for example, the <tt>Person</tt> has an attribute with that name. 
  class DynamicFinderMatch
    def self.match(method)
      df_match = self.new(method)
      df_match.finder ? df_match : nil
    end

    def initialize(method)
      @finder = :first
      @bang   = false
      @instantiator = nil

      case method.to_s
      when /^find_(all_by|last_by|by)_([_a-zA-Z]\w*)$/
        @finder = :last if $1 == 'last_by'
        @finder = :all if $1 == 'all_by'
        names = $2
      when /^find_by_([_a-zA-Z]\w*)\!$/
        @bang = true
        names = $1
      when /^find_or_(initialize|create)_by_([_a-zA-Z]\w*)$/
        @instantiator = $1 == 'initialize' ? :new : :create
        names = $2
      else
        @finder = nil
      end
      @attribute_names = names && names.split('_and_')
    end

    attr_reader :finder, :attribute_names, :instantiator

    def finder?
      !@finder.nil? && @instantiator.nil?
    end

    def instantiator?
      @finder == :first && !@instantiator.nil?
    end

    def creator?
      @finder == :first && @instantiator == :create
    end

    def bang?
      @bang
    end
  end
end
