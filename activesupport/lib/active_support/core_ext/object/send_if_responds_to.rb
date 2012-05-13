class Object

  # Sends +method_name+ to receiver along with any passed arguments, but
  # only if the receiver responds to +method_name+.
  # Returns +false+ if receiver doesn't respond to +method_name+.
  #
  # ==== Examples
  #
  # Without +send_if_responds_to+:
  #   if @post.responds_to? :extra_attribute
  #     @post.extra_attribute
  #   end
  #
  # With +send_if_responds_to+:
  #   @post.send_if_responds_to(:extra_attribute)
  def send_if_responds_to(method_name, *args)
    respond_to?(method_name) && send(method_name, *args)
  end

end

