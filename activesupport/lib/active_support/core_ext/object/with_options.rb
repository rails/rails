require 'active_support/option_merger'

class Object
  # An elegant way to factor duplication out of options passed to a series of
  # method calls. Each method called in the block, with the block variable as
  # the receiver, will have its options merged with the default +options+ hash
  # provided. Each method called on the block variable must take an options
  # hash as its final argument.
  #
  # Without with_options, this code contains duplication:
  #
  #   class Account < ActiveRecord::Base
  #     has_many :customers, :dependent => :destroy
  #     has_many :products,  :dependent => :destroy
  #     has_many :invoices,  :dependent => :destroy
  #     has_many :expenses,  :dependent => :destroy
  #   end
  #
  # Using with_options, we can remove the duplication:
  #
  #   class Account < ActiveRecord::Base
  #     with_options :dependent => :destroy do |assoc|
  #       assoc.has_many :customers
  #       assoc.has_many :products
  #       assoc.has_many :invoices
  #       assoc.has_many :expenses
  #     end
  #   end
  #
  # It can also be used with an explicit receiver:
  #
  #   map.with_options :controller => "people" do |people|
  #     people.connect "/people",     :action => "index"
  #     people.connect "/people/:id", :action => "show"
  #   end
  #
  def with_options(options)
    yield ActiveSupport::OptionMerger.new(self, options)
  end
end
