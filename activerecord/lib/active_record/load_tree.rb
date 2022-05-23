# frozen_string_literal: true

module ActiveRecord
  module LoadTree
    def _create_load_tree_node(creator: self, parent: nil, siblings: [], child_name: nil, child_type: nil)
      @_load_tree_node = ActiveRecord::LoadTree::Node.new(
        creator: creator,
        parent: parent,
        siblings: siblings,
        child_name: child_name,
        child_type: child_type,
      ).set_records
    end

    def _load_tree_node
      @_load_tree_node || ActiveRecord::LoadTree::Node.new(creator: self, siblings: [])
    end

    def _create_root_load_tree_node(siblings:)
      return unless ActiveRecord.load_tree_enabled
      _create_load_tree_node(creator: self, siblings: siblings).set_records
    end

    def _create_association_load_tree_node(parent:, siblings:, child_name:)
      return unless ActiveRecord.load_tree_enabled
      _create_load_tree_node(creator: self, parent: parent, siblings: siblings, child_name: child_name, child_type: :association).set_records
    end

    class Node
      # SiblingSizeLimit is the maximum number of siblings we will track. This
      # Is limited because preloading can blow up if we have a lot of siblings.
      attr_reader :model_class_name
      attr_accessor :siblings, :parent, :children, :child_type, :child_name

      # Create a Load Tree instance representing the loaded record and its place in the overall
      # hierarchy of the object tree. Any passed parents or sibilings should also include the load_tree
      # instance on themselves.
      #
      # creator: The record that owns the tree
      # parent: Instance that is the parent of the loaded record.
      # siblings: Instances that were loaded at the same time as the loaded model.
      # child_name: The name of the child that was loaded as referred to by the parent.
      # child_type: Type of child loading method, for example associations from active record.
      def initialize(creator:, parent: nil, siblings: [], child_name: nil, child_type: nil)
        @parent = parent
        @model_class_name = creator.class.name
        @child_name = child_name
        @children = []
        @siblings = siblings
        @child_type = child_type unless root?
      end

      def set_records
        select_allowed_siblings
        parent._load_tree_node.add_loaded_child(child_name) unless parent.nil? || child_name.nil?
        self
      end

      # Does this load tree belong to a parent?
      def root?
        parent.nil?
      end

      # The full call path to the parent of this load tree. Traverses up the load tree
      # checking if the current load tree is the the root, if it is then it returns
      # the class name of the record for the root element, if not it returns the child
      # name that was used to instantiate the current load tree's record. This will put together
      # a full method chain.
      #
      # parent = Person.find(1)
      # child = parent.children.first
      # child._load_tree.full_load_call_path # => "Person.children"
      #
      def full_load_path
        return model_class_name if root?
        parent._load_tree_node.full_load_path + "." + child_name.to_s
      end

      # Add an child name to the list of loaded children.
      def add_loaded_child(child_name)
        return if child_name.nil? || @children.include?(child_name)
        @children << child_name
      end

      private
        # We only want to keep sibling of the same class type as the creator
        # This ensures we will not try to preload any children that may not
        # exist on some of the sibling which were loaded because of STI.
        def select_allowed_siblings
          @siblings = siblings.select { |s| s.class.name == model_class_name }.compact
        end
    end
  end
end
