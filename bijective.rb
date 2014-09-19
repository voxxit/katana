class Bijective

  $arr  = ENV["ALPHABET"].split //
  $base = $arr.length

  # integer -> string
  def self.encode(i)
    return $arr[0] if i == 0

    "".tap do |s|
      s << $arr[i.modulo($base)] and i /= $base while i > 0
      s.reverse
    end
  end

  # string -> integer
  def self.decode(s)
    0.tap { |i| s.each_char { |c| i = i * $base + $arr.index(c) } }
  end

end
