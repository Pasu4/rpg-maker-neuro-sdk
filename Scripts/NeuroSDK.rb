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

    attr_reader :connected

    #------------------------------------------------------------------------
    #   Private functions
    #------------------------------------------------------------------------

    private

    def main()
      result = ""
      # waited_frames = 0
      while true
        Fiber.yield while @socket.nil?

        available = @socket.select(0)  # Check if buffer has data
        # puts "available: #{available}"

        if available > 0
          buffer = @socket.recv(1024)      # Read up to 1024 bytes
          buffer.gsub!(0.chr, "")           # Remove null characters
          result += buffer
          # puts "buffer: #{buffer}, result: #{result}"
          # puts "buffer.count(\"\\n\"): #{buffer.count("\n")}"
          if result.count("\n") > 0   # End after a newline is encountered
            @command, result = result.split("\n", 2)
            handle_command
          end
        else
          # puts "Waiting 1 frame (#{waited_frames})"
          # waited_frames += 1
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
    NeuroSDK.send_context($game_message.all_text) if NeuroSDK.connected
    _neurosdk_process_all_text
  end
end
