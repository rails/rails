module ActiveRecord

  # = Active Record Dynamic Finder Match
  #
  # Refer to ActiveRecord::Base documentation for Dynamic attribute-based finders for detailed info
  #
  class DynamicFinderMatch
    def self.match(method)
      finder       = :first
      bang         = false
      instantiator = nil

      case method.to_s
      when /^find_(all_|last_)?by_([_a-zA-Z]\w*)$/
        finder = :last if $1 == 'last_'
        finder = :all if $1 == 'all_'
        names = $2
      when /^find_by_([_a-zA-Z]\w*)\!$/
        bang = true
        names = $1
      when /^find_or_(initialize|create)_by_([_a-zA-Z]\w*)$/
        instantiator = $1 == 'initialize' ? :new : :create
        names = $2
      else
        return nil
      end

      new(finder, instantiator, bang, names.split('_and_'))
    end

    def initialize(finder, instantiator, bang, attribute_names)
      @finder          = finder
      @instantiator    = instantiator
      @bang            = bang
      @attribute_names = attribute_names
    end

    attr_reader :finder, :attribute_names, :instantiator

    def finder?
      @finder && !@instantiator
    end

    def instantiator?
      @finder == :first && @instantiator
    end

    def creator?
      @finder == :first && @instantiator == :create
    end

    def bang?
      @bang
    end
  end
end
