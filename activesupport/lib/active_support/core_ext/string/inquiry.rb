require 'active_support/string_inquirer'

class String
  # Wraps the current string in the <tt>ActiveSupport::StringInquirer</tt> class,
  # which gives you a prettier way to test for equality.
  #
  #   env = 'production'.inquiry
  #   env.production?  # => true
  #   env.development? # => false
  #
  # The option +restricted_to+ can be set to an array so the inquirer only
  # responds to a specific set of questions.
  #
  #   status = 'active'.inquiry(restricted_to: ['pending', 'active', 'finished'])
  #   status.pending?  # => false
  #   status.active?   # => true
  #   status.canceled? # => raises NoMethodsError
  def inquiry(restricted_to: nil)
    ActiveSupport::StringInquirer.new(self, restricted_to: restricted_to)
  end
end
