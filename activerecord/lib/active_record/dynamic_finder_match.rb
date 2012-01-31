module ActiveRecord

  # = Active Record Dynamic Finder Match
  #
  # Refer to ActiveRecord::Base documentation for Dynamic attribute-based finders for detailed info
  #
  class DynamicFinderMatch
    def self.match(method)
      method = method.to_s
      klass = [FindBy, FindByBang, FindOrInitializeCreateBy].find do |_klass|
        _klass.matches?(method)
      end
      klass.new(method) if klass
    end

    def self.matches?(method)
      method =~ self::METHOD_PATTERN
    end

    def initialize(method)
      @finder = :first
      @instantiator = nil
      match_data = method.match(self.class::METHOD_PATTERN)
      @attribute_names = match_data[-1].split("_and_")
      initialize_from_match_data(match_data)
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

    def valid_arguments?(arguments)
      arguments.size >= @attribute_names.size
    end

    private

    def initialize_from_match_data(match_data)
    end
  end

  class FindBy < DynamicFinderMatch
    METHOD_PATTERN = /^find_(all_|last_)?by_([_a-zA-Z]\w*)$/

    def initialize_from_match_data(match_data)
      @finder = :last if match_data[1] == 'last_'
      @finder = :all if match_data[1] == 'all_'
    end
  end

  class FindByBang < DynamicFinderMatch
    METHOD_PATTERN = /^find_by_([_a-zA-Z]\w*)\!$/

    def bang?
      true
    end
  end

  class FindOrInitializeCreateBy < DynamicFinderMatch
    METHOD_PATTERN = /^find_or_(initialize|create)_by_([_a-zA-Z]\w*)$/

    def initialize_from_match_data(match_data)
      @instantiator = match_data[1] == 'initialize' ? :new : :create
    end

    def valid_arguments?(arguments)
      arguments.size == 1 && arguments.first.is_a?(Hash) || super
    end
  end
end
