# frozen_string_literal: true

module ConstantResolver
  def const_missing(name)
    return super if constants.empty?

    constants.each do |const_name|
      const = const_get const_name

      begin
        return const.const_get name
      rescue
        begin
          next
        rescue
          return super
        end
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
