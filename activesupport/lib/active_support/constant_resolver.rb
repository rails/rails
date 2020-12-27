# frozen_string_literal: true

module ConstantResolver
  def const_missing(name)
    return super if constants.empty? || self == Object

    constants.each do |const_name|
      const = const_get const_name

      begin
        return const.const_get name, false
      rescue
        next const
      end
    end

    super
  end
end

class Class
  prepend ConstantResolver
end

class Module
  prepend ConstantResolver
end
