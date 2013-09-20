require 'active_support/inflector/methods'

# TrueClass inflections define new methods on the TrueClass class to transform booleans for different purposes.
# For instance, you can turn true to 'Yes' and false to 'No' using humanize
#
#   true.humanize # => "Yes"
#
class TrueClass
  # Returns Yes for true.
  # Like the String equivalent, this is meant for creating pretty output.
  #
  #   'true'.humanize # => "Yes"
  def humanize
    ActiveSupport::Inflector.humanize_boolean(self)
  end
end
class FalseClass
  # Returns No for false.
  # Like the String equivalent, this is meant for creating pretty output.
  #
  #   'false'.humanize # => "No"
  def humanize
    ActiveSupport::Inflector.humanize_boolean(self)
  end
end