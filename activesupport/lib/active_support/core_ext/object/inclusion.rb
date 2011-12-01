class Object
  # Returns true if this object is included in the argument(s). Argument must be
  # any object which responds to +#include?+ or optionally, multiple arguments can be passed in. Usage:
  #
  #   characters = ["Konata", "Kagami", "Tsukasa"]
  #   "Konata".in?(characters) # => true
  #   
  #   character = "Konata"
  #   character.in?("Konata", "Kagami", "Tsukasa") # => true
  #
  # This will throw an ArgumentError if a single argument is passed in and it doesn't respond
  # to +#include?+.
  def in?(*args)
    if args.length > 1
      args.include? self
    else
      another_object = args.first
      if another_object.respond_to? :include?
        another_object.include? self
      else
        raise ArgumentError.new("The single parameter passed to #in? must respond to #include?")
      end
    end
  end
end
