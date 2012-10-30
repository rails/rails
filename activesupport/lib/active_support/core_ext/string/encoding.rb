require 'active_support/deprecation'

class String
  def encoding_aware?
    ActiveSupport::Deprecation.warn 'String#encoding_aware? is deprecated'
    true
  end
end
