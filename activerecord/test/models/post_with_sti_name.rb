class PostWithStiName < Post
  def self.sti_name
    name.underscore
  end

  # Use a different column to avoid conficts with standard Post class STI mechanism
  def self.inheritance_column
    :sti_type
  end
end
