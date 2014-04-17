class Array

  # Splits or iterates over the array in columns of size +number+.
  #
  #   %w(1 2 3 4 5 6 7 8 9 10).in_columns_of(4) {|column| p column}
  #   ["1", "5", "9"]
  #   ["2", "6", "10"]
  #   ["3", "7"]
  #   ["4", "8"]
  #
  #   %w(1 2 3 4 5 6 7 8 9 10).in_columns_of(4,2) {|column| p column}
  #   ["3","7"],
  #   ["4","8"]
  #   ["1","5","9"]
  #   ["2","6","10"]

  def in_columns_of(n_of_columns, index = 0)

    columns = self.reduce(n_of_columns.times.map{ [] }) do |buff,e|
                index = 0 if index >= n_of_columns

                buff[index] << e
                index += 1

                buff
              end

    if block_given?
      columns.each { |c| yield(c) }
    else
      columns
    end
  end

end
