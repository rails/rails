module ActiveRecord

  # = Active Record Dynamic Finder Match
  #
  # Refer to ActiveRecord::Base documentation for Dynamic attribute-based finders for detailed info
  #
  class DynamicFinderMatch
    def self.match(method)
      [ FindBy, FindByBang, FindOrInitializeCreateBy ].each do |klass|
        o = klass.match(method.to_s)
        return o if o
      end
      nil
    end

    def initialize(finder, names, instantiator = nil)
      @finder          = finder
      @instantiator    = instantiator
      @attribute_names = names.split('_and_')
    end

    attr_reader :finder, :attribute_names, :instantiator

    def finder?
      @finder && !@instantiator
    end

    def creator?
      @finder == :first && @instantiator == :create
    end

    def instantiator?
      @instantiator
    end

    def bang?
      false
    end
  end

  class FindBy < DynamicFinderMatch
    def self.match(method)
      if method =~ /^find_(all_|last_)?by_([_a-zA-Z]\w*)$/
        new($1 == 'last_' ? :last : $1 == 'all_' ? :all : :first, $2)
      end
    end
  end

  class FindByBang < DynamicFinderMatch
    def self.match(method)
      if method =~ /^find_by_([_a-zA-Z]\w*)\!$/
        new(:first, $1)
      end
    end

    def bang?
      true
    end
  end

  class FindOrInitializeCreateBy < DynamicFinderMatch
    def self.match(method)
      instantiator = nil
      if method =~ /^find_or_(initialize|create)_by_([_a-zA-Z]\w*)$/
        new(:first, $2, $1 == 'initialize' ? :new : :create)
      end
    end
  end
end
