require 'active_support/symbol_inquirer'

class Symbol
  # Wraps the current symbol in the <tt>ActiveSupport::SymbolInquirer</tt> class,
  # which gives you a prettier way to test for equality.
  #
  #   env = :production.inquiry
  #   env.production?  # => true
  #   env.development? # => false
  def inquiry
    ActiveSupport::SymbolInquirer.new(self)
  end
end
