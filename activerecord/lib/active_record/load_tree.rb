# frozen_string_literal: true

module ActiveRecord
  module LoadTree
    def _create_load_tree_node(creator: self, parents: [], siblings: [])
      parent_objects = parents.map do |parent_hash|
        Parent.new(parent: parent_hash[:instance],
                   child_name: parent_hash[:child_name],
                   child_type: parent_hash[:child_type])
      end

      @_load_tree_node = ActiveRecord::LoadTree::Node.new(
        creator: creator,
        parents: parent_objects,
        siblings: siblings
      ).set_records
    end

    def _load_tree_node
      @_load_tree_node || ActiveRecord::LoadTree::Node.new(creator: self, siblings: [])
    end

    def _create_root_load_tree_node(siblings:)
      return unless ActiveRecord.load_tree_enabled
      _create_load_tree_node(creator: self, siblings: siblings).set_records
    end

    class Node
      # SiblingSizeLimit is the maximum number of siblings we will track. This
      # Is limited because preloading can blow up if we have a lot of siblings.
      attr_reader :model_class_name
      attr_accessor :siblings, :parents, :children

      # Create a Load Tree instance representing the loaded record and its place in the overall
      # hierarchy of the object tree. Any passed parents or sibilings should also include the load_tree
      # instance on themselves.
      #
      # creator: The record that owns the tree
      # parents: Instances that are the parents of the loaded record.
      # siblings: Instances that were loaded at the same time as the loaded model.
      def initialize(creator:, parents: [], siblings: [])
        @parents = parents
        @model_class_name = creator.class.name
        @children = []
        @siblings = siblings
      end

      def set_records
        select_allowed_siblings
        parents.each do |parent|
          parent.parent._load_tree_node.add_loaded_child(parent.child_name) unless parent.child_name.nil?
        end
        self
      end

      # Does this load tree belong to a parent?
      def root?
        parents.empty?
      end

      # Add an child name to the list of loaded children.
      def add_loaded_child(child_name)
        return if child_name.nil? || @children.include?(child_name)
        @children << child_name
      end

      def add_parent(parent, child_name, child_type)
        return if parent.nil? || @parents.include?(parent)
        @parents << Parent.new(parent: parent, child_name: child_name, child_type: child_type)
        set_records
      end

      private
        # We only want to keep sibling of the same class type as the creator
        # This ensures we will not try to preload any children that may not
        # exist on some of the sibling which were loaded because of STI.
        def select_allowed_siblings
          @siblings = siblings.select { |s| s.class.name == model_class_name }.compact
        end
    end

    class Parent
      attr_accessor :parent, :child_name, :child_type

      def initialize(parent:, child_name:, child_type:)
        @parent = parent
        @child_name = child_name
        @child_type = child_type
      end

      def ==(o)
        o.class == self.class && o.parent == parent && o.child_name == child_name && o.child_type == child_type
      end
    end
  end
end
