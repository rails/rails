  class DirtyModel
    include ActiveModel::Dirty
    include ActiveModel::Validations

    define_attribute_methods :name, :color, :size

    def initialize
      @name = nil
      @color = nil
      @size = nil
      @new_record = true
    end

    def name
      @name
    end

    def name=(val)
      name_will_change!
      @name = val
    end

    def color
      @color
    end

    def color=(val)
      color_will_change! unless val == @color
      @color = val
    end

    def size
      @size
    end

    def size=(val)
      attribute_will_change!(:size) unless val == @size
      @size = val
    end

    def save
      changes_applied
      @new_record = false
    end

    def reload
      clear_changes_information
    end

    def deprecated_reload
      reset_changes
    end

    def new_record?
      @new_record
    end
  end
