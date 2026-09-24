class ScriptedRandom
  def initialize(*numbers)
    @numbers = numbers
  end

  def random_number(limit)
    value = @numbers.shift
    raise "Random source failed" if value.nil?
    raise "Invalid test draw" unless (0...limit).cover?(value)
    value
  end
end
