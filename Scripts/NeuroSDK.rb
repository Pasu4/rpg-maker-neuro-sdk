#==============================================================================
# RPG Maker VX Ace Neuro SDK
#------------------------------------------------------------------------------
# Neuro integration / SDK for RPG Maker.
# See https://github.com/Pasu4/rpg-maker-neuro-sdk for more information.
#
# Author: Pasu4
# Version: 0.1.0
#
# Based on:
# https://lthzelda.wordpress.com/2010/04/28/rm-4-tcp-sockets-in-rpg-maker-vx/
# https://forum.chaos-project.com/index.php?topic=14121.0
#==============================================================================

###############################################################################
#                              CONFIGURATION                                  #
###############################################################################

# The address the proxy is running on.
HOST = "127.0.0.1"
# The port the proxy is running on.
PORT = 7689
# # The maximum number of frames to wait for a command.
# SOCKET_TIMEOUT = 60

###############################################################################
#                           END OF CONFIGURATION                              #
###############################################################################

#----------------------------------------------------------------------------
#   Utility
#----------------------------------------------------------------------------

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
      end
      result.map(&:chr).join
    end
  end
end

class SchemaBuilder
  class << self
    # Shorthand for `SchemaBuilder.new.types([:string])`.
    def string
      SchemaBuilder.new.types([:string])
    end

    # Shorthand for `SchemaBuilder.new.types([:boolean])`.
    def boolean
      SchemaBuilder.new.types([:boolean])
    end

    # Shorthand for `SchemaBuilder.new.types([:integer])`.
    def integer
      SchemaBuilder.new.types([:integer])
    end

    # Shorthand for `SchemaBuilder.new.types([:number])`.
    def number
      SchemaBuilder.new.types([:number])
    end

    # Shorthand for `SchemaBuilder.new.types([:null])`.
    def null
      SchemaBuilder.new.types([:null])
    end

    # Shorthand for `SchemaBuilder.new.types([:array]).items(items)`.
    # @param items [SchemaBuilder] Schema for the items of the array.
    def array(items)
      SchemaBuilder.new
        .types([:array])
        .items(items)
    end

    # Shorthand for `SchemaBuilder.new.types([:object]).properties(properties)`.
    # @param properties [Hash<String, SchemaBuilder>] A hash mapping property
    #   names to sub-schemas.
    def object(properties)
      SchemaBuilder.new
        .types([:object])
        .properties(properties)
    end

    # Shorthand for `SchemaBuilder.new.enum(enum)`.
    # @param enum [Array] Array of accepted values.
    def enum(enum)
      SchemaBuilder.new
        .enum(enum)
    end

    # Escape a string so it can be pasted into a JSON string.
    # @param string [String] The string to escape.
    # @return [String] The escaped string.
    def escape(string)
      string
        .gsub(/["\\]/, "\\\\\\&")
        .gsub(/[\b]/, "\\\\b")
        .gsub(/\f/, "\\\\f")
        .gsub(/\n/, "\\\\n")
        .gsub(/\r/, "\\\\r")
        .gsub(/\t/, "\\\\t")
        # leaving out \u#### because no
    end

    # @param value [String, Integer, Float, Boolean, nil] The value to convert
    #   to a JSON value. Does not support arrays and objects.
    # @return [String] The JSON value.
    def json_value(value)
      if value.is_a? String
        return '"' + escape(value) + '"'
      elsif value.is_a?(Integer) || value.is_a?(Float) || value.is_a?(TrueClass) || value.is_a?(FalseClass)
        return value.to_s
      elsif value.nil?
        return 'null'
      end

      $stderr.puts "Error: Class #{value.class} is not supported."
    end
  end

  def optional?; @optional end

  def initialize
    @optional = false
    @types = []
  end

  # Set the accepted types for the schema.
  # @param types [Array<:string, :boolean, :integer, :number, :array, :object>]
  #   The accepted types for the schema.
  # @return [SchemaBuilder] Itself for chaining.
  def types(types)
    @types = types
    self
  end

  # @param types [Array<:string, :boolean, :integer, :number>]
  # @return [SchemaBuilder] Itself for chaining.
  def items(items)
    @items = items
    self
  end

  # @param properties [Hash<String, SchemaBuilder>] A hash mapping property
  #   names to sub-schemas.
  # @return [SchemaBuilder] Itself for chaining.
  def properties(properties)
    @properties = properties
    self
  end

  # @param enum [Array] Array of accepted values. Only supports primitives.
  # @return [SchemaBuilder] Itself for chaining.
  def enum(enum)
    @enum = enum
    self
  end

  # Set the schema as optional. This means that the property may be omitted
  #   from the object.
  # @return [SchemaBuilder] Itself for chaining.
  def optional
    @optional = true
    self
  end

  # Set a minimum value for the integer or number.
  # @param min [Integer, Float] The minimum value.
  # @param exclusive [Boolean] Whether the minimum value itself should be
  #   excluded from the range.
  # @return [SchemaBuilder] Itself for chaining.
  def min(min, exclusive = false)
    @min = min
    @minExclusive = exclusive
    self
  end

  # Set a maximum value for the integer or number.
  # @param max [Integer, Float] The maximum value.
  # @param exclusive [Boolean] Whether the maximum value itself should be
  #   excluded from the range.
  # @return [SchemaBuilder] Itself for chaining.
  def max(max, exclusive = false)
    @max = max
    @maxExclusive = exclusive
    self
  end

  # Set a minimum number of items for the array.
  # @param min [Integer] The minimum number of items.
  # @return [SchemaBuilder] Itself for chaining.
  def minItems(min)
    @minItems = min
    self
  end

  # Set a maximum number of items for the array.
  # @param max [Integer] The maximum number of items.
  # @return [SchemaBuilder] Itself for chaining.
  def maxItems(max)
    @maxItems = max
    self
  end

  # @param description [String] The description of the schema.
  # @return [SchemaBuilder] Itself for chaining.
  def description(description)
    @description = description
    self
  end

  # Build the JSON schema.
  # @return [String] The string representing the schema.
  def build
    result = "{"
    comma = false

    # type
    if @types.size == 1
      comma = true
      result << '"type":"' << @types[0].to_s << '"'
    elsif @types.size > 1
      comma = true
      result << '"type":["' << @types.map(&:to_s).join('","') << '"]'
    end

    # description
    unless @description.nil?
      result << ',' if comma
      comma = true
      result << '"description":"' << SchemaBuilder.escape(@description) << '"'
    end

    # minimum
    unless @min.nil?
      result << ',' if comma
      comma = true
      result << (@minExclusive ? '"exclusiveMinimum":' : '"minimum":') << @min.to_s
    end

    # maximum
    unless @max.nil?
      result << ',' if comma
      comma = true
      result << (@maxExclusive ? '"exclusiveMaximum":' : '"maximum":') << @max.to_s
    end

    # enum
    unless @enum.nil?
      result << ',' if comma
      comma = true
      result << '"enum":[' << @enum.map {|item| SchemaBuilder.json_value(item)} .join(',') << ']'
    end

    # properties
    unless @properties.nil?
      result << ',' if comma
      comma = true
      propcomma = false
      result << '"properties":{'
      @properties.each do |key, value|
        result << ',' if propcomma
        propcomma = true
        result << '"' << key << '":' << value.build  # Recursively build properties
      end
      result << "}"
    end

    # required
    required_properties = @properties.nil? ? [] : @properties.filter_map {|key, value| key unless value.optional?}
    if required_properties.size > 0
      result << ',' if comma
      comma = true
      result << '"required":["' << required_properties.join('","') << '"]'
    end

    # items
    unless @items.nil?
      result << ',' if comma
      comma = true
      result << '"items":' << @items.build
    end

    # minItems
    unless @minItems.nil?
      result << ',' if comma
      comma = true
      result << '"minItems":' << @minItems.to_s
    end

    # maxItems
    unless @maxItems.nil?
      result << ',' if comma
      comma = true
      result << '"maxItems":' << @maxItems.to_s
    end

    result << "}"
  end
end

# Contains methods for communicating with the Neuro API.
module NeuroSDK
  class << self
    #--------------------------------------------------------------------------
    #   Class variables
    #--------------------------------------------------------------------------

    # Whether the SDK is connected to the proxy server.
    @connected = false

    # The message queue from the socket.
    # It will only be valid for a single frame after joining.
    @command = nil

    # The TCP socket.
    @socket = nil

    # The main fiber
    @fiber = Fiber.new { main }

    def connected?
      @connected
    end

    #------------------------------------------------------------------------
    #   Private functions
    #------------------------------------------------------------------------

    private

    def main()
      result = ""
      while true
        Fiber.yield while @socket.nil?

        available = @socket.select(0)  # Check if buffer has data

        if available > 0
          buffer = @socket.recv(1024)      # Read up to 1024 bytes
          buffer.gsub!(0.chr, "")           # Remove null characters
          result += buffer
          if result.count("\n") > 0   # End after a newline is encountered
            @command, result = result.split("\n", 2)
            handle_command
          end
        else
          Fiber.yield
        end
      end

      if waited_frames >= max_wait_frames
        result = ""
      end
    end

    def handle_command
      id, data = @command.split(":", 2)
      puts "Got command #{@command}"

      case id
      when "ok"
        # Give joined fibers time to react to the response
        Fiber.yield
      else
        $stderr.puts "Error: Got unknown command '#{@command}'"
      end
      @command = nil
    end

    # Wait for a command from Neuro.
    # - **timeout:**
    #   Timeout in frames. Default is 3600 (1 minute).
    def join(timeout = 3600)
      frames = 0
      while frames < timeout
        if @command != nil
          command = @command  # Cache so it doesn't get deleted
          @command = nil
          return command
        end
        frames += 1
        Fiber.yield
      end
      $stderr.puts "Error: Server took too long to respond (expected a response within #{timeout/60}s)."
      nil
    end

    #------------------------------------------------------------------------
    #   Public functions
    #------------------------------------------------------------------------

    public

    # Frame update (internal use).
    def update
      @fiber = Fiber.new { main } unless @fiber
      @fiber.resume
    end

    # Connect to the Neuro API proxy server.
    def connect
      if @connected
        $stderr.puts "Warning: Attempted to connect while already connected."
        return
      end
      # Create the socket
      @socket = TCPSocket.new HOST, PORT
      # Wait for the server to send the OK signal
      @connected = join(60) == "ok"
      if !@connected
        $stderr.puts "Error: Did not receive OK from server."
      end
      @connected
    end

    # Sends a context message to Neuro.
    def send_context(context)
      @socket.send("context:#{NeuroSDKUtils.encode64(context)}")
    end
  end
end

#----------------------------------------------------------------------------
#   Hooks
#----------------------------------------------------------------------------

class Scene_Base
  alias_method :_neurosdk_update, :update

  def update
    _neurosdk_update
    NeuroSDK.update
  end
end

class Window_Message
  alias_method :_neurosdk_process_all_text, :process_all_text

  def process_all_text
    # Send text to Neuro when it is printed on screen
    NeuroSDK.send_context($game_message.all_text) if NeuroSDK.connected?
    _neurosdk_process_all_text
  end
end
