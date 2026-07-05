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
# The name of the game used for the Neuro API
GAME = "RPG Maker Game"

###############################################################################
#                           END OF CONFIGURATION                              #
###############################################################################

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

  # @param enum [Array] Array of accepted values.
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

  # Add additional data to the schema.
  # @param meta [Hash] A hash containing the additional data.
  # @return [SchemaBuilder] Itself for chaining.
  def meta(meta)
    @meta = meta
  end

  # Build the JSON schema.
  # @return [Hash] The hash representing the schema.
  def build
    hash = {}

    if @types.size == 1
      hash["type"] = @types[0]
    elsif @types.size > 1
      hash["type"] = @types
    end

    hash["description"] = @description unless @description.nil?

    hash[@minExclusive ? "exclusiveMinimum" : "minimum"] = @min.to_s unless @min.nil?

    hash[@maxExclusive ? "exclusiveMaximum" : "maximum"] = @max.to_s unless @max.nil?

    hash["enum"] = @enum unless @enum.nil?

    unless @properties.nil?
      property_hash = {}
      hash["properties"] = property_hash
      @properties.each do |key, value|
        property_hash[key] = value.build  # Recursively build properties
      end
    end

    required_properties = @properties.nil? ? [] : @properties.filter_map {|key, value| key unless value.optional?}
    hash["required"] = required_properties unless required_properties.empty?

    hash["items"] = @items.build unless @items.nil?

    hash["minItems"] = @minItems unless @minItems.nil?

    hash["maxItems"] = @maxItems unless @maxItems.nil?

    hash.merge!(@meta)

    return hash
  end
end

class NeuroAction
  # The name of the action.
  attr_reader :name
  # `((Hash, nil)) -> NeuroActionResult` callback that is called when the action is executed.
  attr_accessor :callback

  # Create a new action with a name and a description.
  # @param name [String] The name of the action. Must be all lowercase with
  #   underscores.
  # @param description [String] The description of the action that Neuro will
  #   get to read.
  # @param schema [SchemaBuilder] The schema builder to build the schema on
  #   registration.
  # @param callback [Proc] `((Hash, nil)) -> NeuroActionResult` callback that is called
  #   when the action is executed.
  def initialize(name, description, schema = nil, callback = lambda { |_| NeuroActionResult.new true })
    @name = name
    @description = description
    @schema = schema
    @callback = callback
  end

  # Serialize the action into a hash.
  # @return [Hash] The JSON representation of the action.
  def serialize
    hash = {
      "name" => @name,
      "description" => @description,
    }
    hash["schema"] = @schema.build unless @schema.nil?
    return hash
  end
end

class NeuroActionResult
  # @param success [String] If `true` and an action force is active, Neuro is
  #   instructed to retry executing an action.
  # @param message [String, nil] An optional message to send Neuro along with
  #   the result. If the action failed, it should contain the reason.
  def initialize(success, message = nil)
    @id = nil
    @success = success
    @message = message
  end

  # Serialize this object to a hash.
  # @return [Hash]
  def serialize
    result = {
      "id" => @id,
      "success" => @success,
    }
    result["message"] = @message unless @message.nil?
    return result
  end

  attr_writer :id
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
    # @type [Hash, nil]
    @command = nil

    # The TCP socket.
    @socket = nil

    # # A hash of configuration values sent by the server.
    # # @type [Hash{String => String}]
    # @config = {}

    # The main fiber
    @fiber = Fiber.new { main }

    # Array of registered actions
    # @type [Array<NeuroAction>]
    @actions = []

    def connected?
      @connected
    end

    #------------------------------------------------------------------------
    #   Private functions
    #------------------------------------------------------------------------

    private

    def main()
      # Initialize
      @game = GAME if @game.nil?

      result = ""
      while true
        Fiber.yield while @socket.nil?

        available = @socket.select(0)  # Check if buffer has data

        if available > 0
          buffer = @socket.recv(1024)      # Read up to 1024 bytes
          buffer.gsub!(0.chr, "")           # Remove null characters
          result += buffer
          if result.count("\n") > 0   # End after a newline is encountered
            command_str, result = result.split("\n", 2)
            @command = JSON.parse(command_str)
            handle_command
          end
        else
          Fiber.yield
        end
      end
    end

    def handle_command
      if @command["command"].nil?
        $stderr.puts "Error: Invalid format for command."
      end
      case @command["command"]
      when "startup"
        handle_startup(@command["data"])
      when "action"
        handle_action(@command["data"])
      when "proxy/connected"  # Custom command of the proxy
        @connected = true
      else
        $stderr.puts "Error: Got unknown command '#{@command}'"
      end
      # Give joined fibers time to react to the response
      Fiber.yield
      @command = nil
    end

    # Send a command over the TCP socket.
    # @param command [String] The command ID.
    # @param data [Object] The command data to send.
    def send_command(command, data = nil)
      message = {
        "command" => command,
        "game" => @game,
      }
      message["data"] = data unless data.nil?
      @socket.send(JSON.stringify(message) + "\n")
    end

    # Wait for a command from Neuro.
    # @param timeout [Integer] Timeout in frames. Default is 3600 (1 minute).
    # @return [String, nil] The parsed command, or `nil` if no command is
    #   received within the timeout.
    def join(timeout = 3600)
      frames = 0
      while frames < timeout
        return @command unless @command.nil?
        frames += 1
        Fiber.yield
      end
      $stderr.puts "Error: Server took too long to respond (expected a response within #{timeout/60.0}s)."
      nil
    end

    # Handle the `startup` command.
    # @param data [Hash] Action data.
    def handle_startup(data)
      @session_id = data["session"]["sessionId"]
      @character_id = data["session"]["characterId"]
      @display_name = data["session"]["displayName"]
    end

    # Handle the `action` command.
    # @param data [Hash] Action data.
    def handle_action(data)
      name = data["name"]
      id = data["id"]
      action = @actions.find {|item| item.name == name}
      action_data = data["data"].nil? ? nil : JSON.parse(data["data"])
      # @type [NeuroActionResult]
      result = action.callback.call(action_data)
      unless result.is_a? NeuroActionResult
        $stderr.puts "Error: Action callback did not return an action result."
      end
      result.id = id
      send_command("action/result", result.serialize)
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
      join(60)
      if !@connected
        $stderr.puts "Error: Did not receive connection confirmation from server."
        return false
      end
      send_command("startup")
      return true
    end

    # Sends a context message to Neuro.
    # @param context [String] The context to send.
    # @param silent [Boolean] If `true`, will not prompt Neuro to respond.
    def send_context(context, silent = false)
      send_command("context", {
        "message" => context,
        "silent" => silent,
      })
    end

    # Register actions with the Neuro API.
    # @param actions [Array<NeuroAction>] The array of actions to register.
    def registerActions(actions)
      action_names = @actions.map(&:name)
      duplicates, non_duplicates = actions.partition {|action| action_names.include?(action.name)}

      if duplicates.size > 0
        $stderr.puts "Warning: Ignoring action(s) with duplicate name: #{duplicates.map(&:name).join(', ')}"
      end
      send_command("actions/register", {
        "actions" => non_duplicates.map(&:serialize),
      })
    end

    # Unregister actions with the specified names.
    # @param action_names [Array<String>] The array of action names to unregister.
    def unregister_actions(action_names)
      @actions.filter! {|item| action_names.include?(item.name) }
      send_command("actions/unregister", {
        "action_names" => action_names,
      })
    end

    # Force Neuro to execute one of the actions listed in `action_names`.
    # @param action_names [Array<string>] The names of actions that Neuro
    #   should execute one of.
    # @param query [String] A string that explains to Neuro what she is
    #   supposed to do.
    # @param state [String, nil] The current state of the game, if applicable.
    #   Can be any format, but Markdown is recommended.
    # @param ephemeral [Boolean] If `true`, Neuro will not remember the `state`
    #   and `query` after executing the action.
    # @param priority [String] The priority (see the API spec). Must be
    #   `"low"`, `"medium"`, `"high"`, or `"critical"`.
    def force_actions(action_names, query, state = nil, ephemeral = false, priority = "low")
      registered_action_names = @actions.map { |action| action.name }
      if action_names.any? { |name| registered_action_names.include?(name) }
        $stderr.puts "Warning: Some forced actions are not registered and will be ignored by Neuro."
      end
      data = {
        "action_names" => action_names,
        "query" => query,
        "ephemeral" => ephemeral,
        "priority" => priority,
      }
      data["state"] = state unless state.nil?
      send_command("actions/force", data)
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
