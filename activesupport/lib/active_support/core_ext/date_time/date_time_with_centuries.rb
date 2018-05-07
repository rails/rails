require "date"
# override DateTime method
class DateTimeWithCenturies < DateTime
  def change(options)
    if options.keys?(:century)
      new_hash = options
        .delete(:century)
        .merge({ years: modified_years(options[:century], options[:years]) })
      return super(new_hash)
    end
    super(options)
  end

  def century
    (self.year / 100).to_i + 1
  end

  private
# calculate century
  def modified_years(century, years=0)
    ((century-1) * 100) + (years % 100)
  end
end
