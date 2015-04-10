module Truthiness
  refine Object do
    FALSE_VALUES = ['0', 'f', 'F', 'false', 'FALSE', 'off', 'OFF', false, 0, nil].to_set

    def falsey?
      FALSE_VALUES.include? self
    end

    def truthy?
      ! falsey?
    end
  end
end
