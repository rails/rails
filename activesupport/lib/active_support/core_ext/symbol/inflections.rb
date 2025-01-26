# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

# Symbol inflections define new methods on the Symbol class to transform names for different purposes.
# For instance, you can figure out the name of a table from the name of a class.
#
#   :ScaleScore.tableize # => :scale_scores
#
class Symbol
  ##
  # :call-seq: camelize(first_letter = :upper)
  #
  # See String#camelize.
  def camelize(...)
    name.camelize(...).to_sym
  end
  alias_method :camelcase, :camelize

  # See String#dasherize.
  def dasherize
    name.dasherize.to_sym
  end

  # See String#underscore.
  def underscore
    name.underscore.to_sym
  end
end
