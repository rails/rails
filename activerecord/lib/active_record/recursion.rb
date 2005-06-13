module ActiveRecord
  # Wraps a guard around #save to make sure that recursive calls don't actually
  # invoke save multiple times. Recursive calls to save can occur quite
  # easily, and unintentionally. Consider the following case:
  #
  #   class Project < ActiveRecord::Base
  #     has_and_belongs_to_many :people
  #     after_create :grant_access_to_admins
  #
  #     def grant_access_to_admins
  #       Person.admins.each do |admin|
  #         admin.projects.push_with_attributes(self, "access_level" => 42)
  #       end
  #     end
  #   end
  #
  #   class Person < ActiveRecord::Base
  #     has_and_belongs_to_many :projects
  #     ...
  #   end
  #
  #   teddy = Person.find_by_name("teddy")
  #   project = Project.new :name => "sumo wrestling"
  #   project.people << teddy
  #   project.save!
  #
  # The #push_with_attributes causes +self+ (the project) to be saved again,
  # even though we're already in the midst of doing a save. This results in
  # "teddy" _not_ being added to the project's people list, because the
  # recursive call resets the new-record status and thus ignores any
  # non-new records in the collection.
  #
  # Thus, the need for a recursive guard on save.
  module Recursion 
    def self.append_features(base) # :nodoc:
      super

      base.class_eval do
        alias_method :save_without_recursive_guard, :save
        alias_method :save, :save_with_recursive_guard
      end
    end    

    # Wrap the save call with a sentinel that prevents saves from occuring if
    # a save is already in progress.
    def save_with_recursive_guard(*args)
      critical = Thread.critical
      Thread.critical = true
      old_save_state = @currently_saving_record
      return true if @currently_saving_record
      @currently_saving_record = true
      Thread.critical = critical

      save_without_recursive_guard(*args)
    ensure
      Thread.critical = critical
      @currently_saving_record = old_save_state
    end
  end
end
