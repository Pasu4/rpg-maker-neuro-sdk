#==============================================================================
# RPG Maker VX Ace Neuro Integration
#------------------------------------------------------------------------------
# Neuro integration / SDK for RPG Maker.
# See https://github.com/Pasu4/rpg-maker-neuro-sdk for more information.
#
# Author: Pasu4
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

def tcptest
  #Create a socket
  s = TCPSocket.new(HOST, PORT)

  #Send a test message
  s.send("Testing...\n")
  #Receive a result from the server
  msg = ""
  while
    buffer = s.recv(1024)    #Read UP TO 1024 bytes
    buffer.gsub!(0.chr, "") #Remove null bytes
    msg += buffer            #Append received data
    break if buffer.count("\n")>0   #Stop if we've reached the newline
  end
  #Done; close the socket, print our message
  s.close()
  print "Received: #{msg}"
end

# Contains methods for communicating with the Neuro API.
module NeuroSDK
  @@connected = false
  def self.connected
    @@connected
  end
  # @socket = nil
  # Receive a command from the socket.
  # - **maxWaitFrames:**
  #   Maximum time to wait in frames.
  #   Default is 18000 (5 minutes).
  # TODO: Figure out cancellation (needs to discard previous message, not sure
  # how to do that yet).
  def self.recv(max_wait_frames = 18000)
    puts "recv called"
    result = ""
    waited_frames = 0
    # canceled = false
    while waited_frames < max_wait_frames
      available = $socket.select(0)  # Check if buffer has data
      puts "available: #{available}"
      # canceled = cancel_on.call
      # break if canceled
      if true
      # if buffer.bytesize > 0
        buffer = $socket.recv(1024)      # Read up to 1024 bytes
        buffer.gsub!(0.chr, "")           # Remove null characters
        result += buffer
        puts "buffer: #{buffer}, result: #{result}"
        puts "buffer.count(\"\\n\"): #{buffer.count("\n")}"
        break if buffer.count("\n") > 0   # End after a newline is encountered
        # TODO: Multiple messages in the buffer might cause problems
      else
        puts "Waiting 1 frame (#{waited_frames})"
        waited_frames += 1
        Fiber.yield
      end
    end
    puts "End of loop"

    if waited_frames >= max_wait_frames
      result = ""
      $stderr.puts "Error: Server took too long to respond (expected a response within #{max_wait_frames/60}s)."
    end
    # result = "" if canceled

    result.chomp # Remove newline
  end

  # Connect to the Neuro API proxy server.
  def self.connect
    # Create the socket
    $socket = TCPSocket.new HOST, PORT
    puts "Created socket."
    # Wait for the server to send the OK signal
    @@connected = self.recv == "ok"
    if !@@connected
      $stderr.puts "Error: Did not receive OK from server."
    end
    @@connected
  end

  # Sends a context message to Neuro.
  def self.send_context(context)
    # self.recv
  end
end

#----------------------------------------------------------------------------
#   Hooks
#----------------------------------------------------------------------------

class Window_Message
  alias_method :_neurosdk_process_all_text, :process_all_text
  
  def process_all_text
    # Send text to Neuro when it is printed on screen
    # DEBUG: Just send the text to the console for now
    puts $game_message.all_text
    _neurosdk_process_all_text 
  end
end
