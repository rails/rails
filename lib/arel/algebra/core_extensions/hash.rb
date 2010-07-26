class Hash
  def bind(relation)
    Hash[map { |key, value|
      [key.bind(relation), value.bind(relation)]
    }]
  end
end
