module AdapterGuards
  def adapter_is(*names)
    names = names.map(&:to_s)
    names.each{|name| verify_adapter_name(name)}
    yield if names.include? adapter_name
  end

  def adapter_is_not(*names)
    names = names.map(&:to_s)
    names.each{|name| verify_adapter_name(name)}
    yield unless names.include? adapter_name
  end

  def adapter_name
    name = ActiveRecord::Base.configurations["unit"][:adapter]
    name = 'oracle' if name == 'oracle_enhanced'
    verify_adapter_name(name)
    name
  end

  def verify_adapter_name(name)
    raise "Invalid adapter name: #{name}" unless valid_adapters.include?(name.to_s)
  end

  def valid_adapters
    %w[mysql postgresql sqlite3 oracle]
  end
end
