class EmailValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors[attribute] << (options[:message] || "is not an email") unless
      value =~ /\A((?:[\w+\-].?)+)@([a-z\d\-]+(?:\.[a-z]+)*\.[a-z]+)\z/i
  end
end