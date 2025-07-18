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

  # See String#classify.
  def classify
    name.classify.to_sym
  end

  # See String#dasherize.
  def dasherize
    name.dasherize.to_sym
  end

  # See String#deconstantize.
  def deconstantize
    name.deconstantize.to_sym
  end

  # See String#demodulize.
  def demodulize
    name.demodulize.to_sym
  end

  # See String#downcase_first.
  def downcase_first
    name.downcase_first.to_sym
  end

  ##
  # :call-seq: foreign_key(separate_class_name_and_id_with_underscore = true)
  #
  # See String#foreign_key.
  def foreign_key(...)
    name.foreign_key(...).to_sym
  end

  ##
  # :call-seq: humanize(capitalize: true, keep_id_suffix: false)
  #
  # See String#humanize.
  def humanize(...)
    name.humanize(...).to_sym
  end

  ##
  # :call-seq: parameterize(separator: "-", preserve_case: false, locale: nil)
  #
  # See String#parameterize.
  #
  # Raises EncodingError if the Symbol#name contains invalid UTF-8
  def parameterize(...)
    name.parameterize(...).to_sym
  end

  ##
  # :call-seq: pluralize(count = nil, locale = :en)
  #
  # See String#pluralize.
  def pluralize(...)
    name.pluralize(...).to_sym
  end

  ##
  # :call-seq: singularize(locale = :en)
  #
  # See String#singularize.
  def singularize(...)
    name.singularize(...).to_sym
  end

  # See String#tableize.
  def tableize
    name.tableize.to_sym
  end

  ##
  # :call-seq: titleize(keep_id_suffix: false)
  #
  # See String#titleize.
  def titleize(...)
    name.titleize(...).to_sym
  end
  alias_method :titlecase, :titleize

  # See String#underscore.
  def underscore
    name.underscore.to_sym
  end

  # See String#upcase_first.
  def upcase_first
    name.upcase_first.to_sym
  end
end
