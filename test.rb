class Foo
  @@connected = false

  def self.connect
    @@connected = true
  end

  def self.connected
    @@connected
  end
end

puts "Foo connected: #{Foo.connected}"
puts "Connecting Foo."
Foo.connect
puts "Foo connected: #{Foo.connected}"
