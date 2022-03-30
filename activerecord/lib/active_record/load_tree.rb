# frozen_string_literal: true

module ActiveRecord
  class LoadTree
    attr_reader :record_class_name, :loaded_associations
    attr_accessor :siblings, :parent, :loaded_association, :association_name

    # Create a Load Tree instance representing the loaded record and its place in the overall
    # hierarchy of the object tree. Any passed parents or sibilings should also include the load_tree
    # instance on themselves.
    #
    # parent: Instance that is the parent of the loaded record.
    # siblings: Instances that were loaded at the same time as the loaded record.
    # association_name: The name of the association that was loaded.
    def initialize(creator: nil, parent: nil, siblings: [], association_name: nil)
      @parent = parent
      @record_class_name = creator.class.name
      @association_name = association_name
      parent._load_tree.add_loaded_association(association_name) unless parent.nil? || association_name.nil?
      @loaded_associations = []
      @siblings = siblings
    end

    def set_records
      select_allowed_siblings
      self
    end

    # Does this load tree belong to a parent?
    def root?
      parent.nil?
    end

    # The full call path to the parent of this load tree. Traverses up the load tree
    # checking if the current load tree is the the root, if it is then it returns
    # the class name of the record for the root element, if not it returns the association
    # name that was used to instantiate the current load tree's record. This will put together
    # a full method chain.
    #
    # parent = Person.find(1)
    # child = parent.children.first
    # child._load_tree.full_load_call_path # => "Person.children"
    #
    def full_load_path
      return record_class_name if root?
      parent._load_tree.full_load_path + "." + association_name.to_s
    end

    # Add an association name to the list of loaded associations.
    def add_loaded_association(association_name)
      return if association_name.nil? || @loaded_associations.include?(association_name)
      @loaded_associations << association_name
    end

    private

    # We only want to keep sibling of the same class type as the creator
    # This ensures we will not try to preload any associations that may not
    # exist on some of the sibling which were loaded because of STI.
    def select_allowed_siblings
      @siblings = siblings.select { |s| s.class.name == @record_class_name }.compact
    end
  end
end
