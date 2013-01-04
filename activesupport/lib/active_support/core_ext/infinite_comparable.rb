require 'active_support/concern'

module InfiniteComparable
  extend ActiveSupport::Concern

  included do
    alias_method_chain :<=>, :infinity
  end

  define_method '<=>_with_infinity' do |other|
    if other.class == self.class
      self.send(:'<=>_without_infinity', other)
    # inf <=> inf
    elsif other.respond_to?(:infinite?) && other.infinite? && respond_to?(:infinite?) && infinite?
      infinite? <=> other.infinite?
    # not_inf <=> inf
    elsif other.respond_to?(:infinite?) && other.infinite?
      -other.infinite?
    # inf <=> not_inf
    elsif respond_to?(:infinite?) && infinite?
      infinite?
    else
      conversion = :"to_#{self.class.name.downcase}"

      other = other.send(conversion) if other.respond_to?(conversion)

      self.send(:'<=>_without_infinity', other)
    end
  end
end
