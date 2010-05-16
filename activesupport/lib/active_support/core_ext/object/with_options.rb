require 'active_support/option_merger'

class Object
  # An elegant way to factor duplication out of options passed to a series of
  # method calls. Each method called in the block, with the block variable as
  # the receiver, will have its options merged with the default +options+ hash
  # provided. Each method called on the block variable must take an options
  # hash as its final argument.
  #
  #   with_options :order => 'created_at', :class_name => 'Comment' do |post|
  #     post.has_many :comments, :conditions => ['approved = ?', true], :dependent => :delete_all
  #     post.has_many :unapproved_comments, :conditions => ['approved = ?', false]
  #     post.has_many :all_comments
  #   end
  #
  # Can also be used with an explicit receiver:
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
