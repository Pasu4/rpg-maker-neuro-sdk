module NeuroSDKUtils
  class << self
    $encode64_table = [
      "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P",
      "Q","R","S","T","U","V","W","X","Y","Z","a","b","c","d","e","f",
      "g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v",
      "w","x","y","z","0","1","2","3","4","5","6","7","8","9","+","/",
    ]
    $decode64_table = Hash[$encode64_table.zip(0...$encode64_table.size)]

    def encode64(string)
      result = []
      chunks = string.bytes.each_slice(3)
      for chunk in chunks
        result.push   chunk[0] >> 2
        result.push  (chunk[0] << 4) & 63
        result[-1] |= chunk[1] >> 4       if chunk.size >= 2
        result.push  (chunk[1] << 2) & 63 if chunk.size >= 2
        result[-1] |= chunk[2] >> 6       if chunk.size >= 3
        result.push   chunk[2]       & 63 if chunk.size >= 3
      end
      result.map { |n| $encode64_table[n] } .join
    end

    def decode64(string)
      result = []
      chunks = string.chars.map { |c| $decode64_table[c] } .each_slice(4)
      for chunk in chunks
        result.push  (chunk[0] << 2) & 255
        result[-1] |= chunk[1] >> 4        if chunk.size >= 2
        result.push  (chunk[1] << 4) & 255 if chunk.size >= 2
        result[-1] |= chunk[2] >> 2        if chunk.size >= 3
        result.push  (chunk[2] << 6) & 255 if chunk.size >= 3
        result[-1] |= chunk[3]             if chunk.size >= 4
        # puts chunk.map { |n| "%06b" % n } .join(" ")
        # puts result[-3..-1].map { |n| "%08b" % n } .join(" ")
      end
      result.map(&:chr).join
    end
  end
end

puts NeuroSDKUtils.encode64("Hello World")
puts NeuroSDKUtils.decode64("SGVsbG8gV29ybGQ")
