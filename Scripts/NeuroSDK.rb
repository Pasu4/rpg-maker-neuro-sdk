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
# Whether Neuro can controll the party command (Fight/Escape)
CAN_PARTY_COMMAND = true

###############################################################################
#                           END OF CONFIGURATION                              #
###############################################################################

# Helper class for building JSON schemas for use in {NeuroAction NeuroActions}.
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

  # @param items [Array<:string, :boolean, :integer, :number>]
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

    hash[@minExclusive ? "exclusiveMinimum" : "minimum"] = @min unless @min.nil?

    hash[@maxExclusive ? "exclusiveMaximum" : "maximum"] = @max unless @max.nil?

    hash["enum"] = @enum unless @enum.nil?

    unless @properties.nil?
      property_hash = {}
      hash["properties"] = property_hash
      @properties.each do |key, value|
        property_hash[key] = value.build  # Recursively build properties
      end
    end

    required_properties = @properties.nil? ? [] : @properties.select {|key, value| !value.optional?} .map {|key, value| key}
    hash["required"] = required_properties unless required_properties.empty?

    hash["items"] = @items.build unless @items.nil?

    hash["minItems"] = @minItems unless @minItems.nil?

    hash["maxItems"] = @maxItems unless @maxItems.nil?

    hash.merge!(@meta) unless @meta.nil?

    return hash
  end
end

# @api private
COMMAND_WINDOW_ACTION_CANCEL = "(cancel)"

# An action that the Neuro API can use to interact with the game.
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
  # @param callback [Proc<NeuroActionResult>(Hash, nil)] Callback that
  #   is called when the action is executed. **DO NOT** use any blocking calls
  #   or {Fiber.yield} in this callback (use {NeuroSDK.async} for that).
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
      name: @name,
      description: @description,
    }
    hash[:schema] = @schema.build unless @schema.nil?
    return hash
  end

  class << self
    # Make an action for a `Window_Selectable`.
    # @param action_name [String] The name of the action.
    # @param description [String] The description of the action.
    # @param window [Window_Selectable] The command window to make a choice in.
    # @param choices [Array<String>] The options to choose from, in the order
    #   they are selectable in the window.
    # @param invalid_choices [Array<Integer>] Indices of choices that should be
    #   ignored. An empty array by default.
    # @return [NeuroAction] An action with the choices.
    def make_selectable_window_action(action_name, description, window, choices, invalid_choices = [])
      valid_choices = choices.dup

      if window.cancel_enabled?
        valid_choices.push(COMMAND_WINDOW_ACTION_CANCEL)
      end

      invalid_choices.sort.reverse.each do |i|
        valid_choices.delete_at(i)
      end

      return NeuroAction.new(
        action_name,
        description,
        SchemaBuilder.object({
          choice: SchemaBuilder.enum(valid_choices)
        }),
        lambda { |data|
          # Check that it is actually one of the options
          unless valid_choices.include?(data["choice"])
            return NeuroActionResult.new false, "Invalid choice. Must be one of: '#{valid_choices.join("', '")}'"
          end

          NeuroSDK.unregister_actions([action_name])
          choice = data["choice"]

          NeuroSDK.async {
            if choice == COMMAND_WINDOW_ACTION_CANCEL
              window.process_cancel
            else
              index = choices.find_index(choice)
              window.select(index)
              Sound.play_cursor  # Normally only played when moving the cursor
              15.times { Fiber.yield }  # Wait for 1/4 second
              window.select(index)  # Select again in case someone moved the selection
              window.process_ok
            end
          }

          return NeuroActionResult.new true
        }
      )
    end
    # Make an action for a `Window_Command`.
    # @param action_name [String] The name of the action.
    # @param description [String] The description of the action.
    # @param window [Window_Command] The command window to make a choice in.
    # @param invalid_choices [Array<Integer>] Indices of choices that should be
    #   ignored. An empty array by default.
    # @return [NeuroAction] An action with the choices.
    def make_command_window_action(action_name, description, window, invalid_choices = [])
      choices = window.instance_variable_get(:@list)
        .select { |item| item[:enabled] }
        .map { |item| item[:name] }

      return NeuroAction.make_selectable_window_action(
        action_name,
        description,
        window,
        choices,
        invalid_choices
      )
    end
  end
end

# The result of a {NeuroAction}, sent back to the Neuro API.
class NeuroActionResult
  attr_reader :success

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
      id: @id,
      success: @success,
    }
    result["message"] = @message unless @message.nil?
    return result
  end

  attr_writer :id
end

# Contains methods for communicating with the Neuro API.
module NeuroSDK
  class << self
    def connected?
      @connected
    end

    def forced?
      @forced
    end

    #------------------------------------------------------------------------
    #   Private functions
    #------------------------------------------------------------------------

    private

    def init
      return if @initialized

      @initialized = true
      # Whether the SDK is connected to the proxy server.
      @connected = false
      # The message queue from the socket.
      # It will only be valid for a single frame after joining.
      # @type [Hash, nil]
      @command = nil
      # The TCP socket.
      @socket = nil
      # The main fiber
      @fiber = Fiber.new { main } if @fiber.nil?
      # Array of registered actions
      # @type [Array<NeuroAction>]
      @actions = []
      # Array of async fibers from action executions
      # @type [Array<Fiber>]
      @async_fibers = []
      # Whether an action force is active.
      # @type [Boolean]
      @forced = false
    end

    def main
      init

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
        command: command,
        game: GAME,
      }
      message[:data] = data unless data.nil?
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
        $stderr.puts "Warning: Action callback did not return an action result. Assuming success."
        result = NeuroActionResult.new true
      end
      result.id = id
      @forced = false if result.success
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

      # Update async fibers
      dead_fibers = []
      @async_fibers.each { |fiber|
        begin
          fiber.resume
        rescue FiberError
          dead_fibers.push(fiber)
        end
      }
      @async_fibers -= dead_fibers
    end

    # Connect to the Neuro API proxy server.
    def connect
      init
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
        message: context,
        silent: silent,
      })
    end

    # Register actions with the Neuro API.
    # @param actions [Array<NeuroAction>] The array of actions to register.
    def register_actions(actions)
      action_names = @actions.map(&:name)
      duplicates, non_duplicates = actions.partition {|action| action_names.include?(action.name)}

      if duplicates.size > 0
        $stderr.puts "Warning: Ignoring action(s) with duplicate name: #{duplicates.map(&:name).join(', ')}"
      end
      @actions.push(*non_duplicates)
      send_command("actions/register", {
        actions: non_duplicates.map(&:serialize),
      })
    end

    # Unregister actions with the specified names.
    # @param action_names [Array<String>] The array of action names to unregister.
    def unregister_actions(action_names)
      @actions.select! {|item| !action_names.include?(item.name) }
      send_command("actions/unregister", {
        action_names: action_names,
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
      unless action_names.all? { |name| registered_action_names.include?(name) }
        $stderr.puts "Warning: Some forced actions are not registered and will be ignored by Neuro."
      end
      data = {
        action_names: action_names,
        query: query,
        ephemeral_context: ephemeral,
        priority: priority,
      }
      data[:state] = state unless state.nil?
      send_command("actions/force", data)
      @forced = true
    end


    # Execute an action asynchronously.
    #
    # @example
    #     NeuroAction.new(
    #       "do_something",
    #       "Do something",
    #       nil,
    #       lambda {
    #         NeuroSDK.async {
    #           60.times { Fiber.yield }  # Wait 1 second
    #
    #           # (Do something)
    #         }
    #         return NeuroActionResult.new true
    #       }
    #     )
    #
    # @param proc [Proc] Code to execute.
    def async(&proc)
      @async_fibers.push (Fiber.new { proc.call })
      nil
    end
  end
end

#----------------------------------------------------------------------------
#   Hooks
#----------------------------------------------------------------------------

# @api private
class Scene_Base
  alias_method :_neurosdk_update, :update

  def update
    _neurosdk_update
    NeuroSDK.update
  end
end

# @api private
class Window_Message
  alias_method :_neurosdk_process_all_text, :process_all_text

  def process_all_text
    # Send text to Neuro when it is printed on screen
    NeuroSDK.send_context($game_message.all_text) if NeuroSDK.connected?
    _neurosdk_process_all_text
  end
end

# @api private
DIALOGUE_CHOICE_ACTION_NAME = "choose_dialogue_option"

# @api private
class Window_ChoiceList
  alias_method :_neurosdk_start, :start
  alias_method :_neurosdk_call_ok_handler, :call_ok_handler
  alias_method :_neurosdk_call_cancel_handler, :call_cancel_handler

  def start
    _neurosdk_start

    return unless NeuroSDK.connected?

    # choice_cancel_type == 0: Cancel disabled
    # choice_cancel_type == 5: Separate branch

    # Register an action to choose an option
    choice_action = NeuroAction.make_command_window_action(
      DIALOGUE_CHOICE_ACTION_NAME,
      "Choose a dialogue option.",
      self
    )
    NeuroSDK.register_actions([choice_action])

    # Force the action
    NeuroSDK.force_actions(
      [DIALOGUE_CHOICE_ACTION_NAME],
      "You need to choose a dialogue option.",
      "Current dialogue:\n\n#{$game_message.all_text}",
    )
  end

  def call_ok_handler
    _neurosdk_call_ok_handler

    return unless NeuroSDK.connected?

    NeuroSDK.unregister_actions([DIALOGUE_CHOICE_ACTION_NAME])
  end

  def call_cancel_handler
    _neurosdk_call_cancel_handler

    return unless NeuroSDK.connected?

    NeuroSDK.unregister_actions([DIALOGUE_CHOICE_ACTION_NAME])
  end
end

# TODO: Window_Command
# TODO: Window_HorzCommand
# TODO: Window_Help
# TODO: Window_Gold
# TODO: Window_MenuCommand
# TODO: Window_MenuStatus
# TODO: Window_MenuActor
# TODO: Window_ItemCategory
# TODO: Window_ItemList
# TODO: Window_SkillCommand
# TODO: Window_SkillStatus
# TODO: Window_SkillList
# TODO: Window_EquipStatus
# TODO: Window_EquipCommand
# TODO: Window_EquipSlot
# TODO: Window_EquipItem
# TODO: Window_Status
# TODO: Window_SaveFile
# TODO: Window_ShopCommand
# TODO: Window_ShopBuy
# TODO: Window_ShopSell
# TODO: Window_ShopNumber
# TODO: Window_ShopStatus
# TODO: Window_NameEdit
# TODO: Window_NameInput
# TODO: Window_NumberInput
# TODO: Window_KeyItem
# TODO: Window_ScrollText
# TODO: Window_MapName

# @api private
class Window_BattleLog
  alias_method :_neurosdk_add_text, :add_text
  alias_method :_neurosdk_replace_text, :replace_text


  # @param text [String] <description>
  def add_text(text)
    _neurosdk_add_text(text)

    unless text.empty?
      NeuroSDK.send_context(text)
    end
  end

  def replace_text(text)
    _neurosdk_replace_text(text)

    unless text.empty?
      NeuroSDK.send_context(text)
    end
  end
end

# @api private
PARTY_COMMAND_ACTION_NAME = "choose_party_action"

# @api private
class Window_PartyCommand
  alias_method :_neurosdk_setup, :setup
  alias_method :_neurosdk_call_ok_handler, :call_ok_handler

  def setup
    _neurosdk_setup

    return unless NeuroSDK.connected? and CAN_PARTY_COMMAND

    choice_action = NeuroAction.make_command_window_action(
      PARTY_COMMAND_ACTION_NAME,
      "Choose an action for the party.",
      self,
      [1]  # DEBUG: Disable escape
    )
    NeuroSDK.register_actions([choice_action])

    # Explain battle state

    # @type [Array<string>]
    # @param member [Game_Actor]
    party = $game_party.members.map { |member|
      member_class = $data_classes[$game_party.members[0].class_id].name
      "- #{member.name} (Level #{member.level} #{member_class}, HP #{member.hp}/#{member.mhp}, MP #{member.mp}/#{member.mmp})"
    }
    # @type [Array<string>]
    # @param member [Game_Enemy]
    enemies = $game_troop.alive_members.map { |member|
      "- #{member.original_name}#{member.plural ? member.letter : ''}"
    }

    state = "Your party consists of:\n\n"
    state << party.join("\n")
    state << "\n\nThere are #{$game_troop.alive_members.size} enemies:\n\n"
    state << enemies.join("\n")
    state << "\n\nYou cannot escape from this battle." unless BattleManager.can_escape?

    NeuroSDK.force_actions(
      [PARTY_COMMAND_ACTION_NAME],
      "What to do?",
      state
    )
  end

  def call_ok_handler
    _neurosdk_call_ok_handler
    return unless NeuroSDK.connected?

    NeuroSDK.unregister_actions([PARTY_COMMAND_ACTION_NAME])
  end
end

# @api private
ACTOR_COMMAND_ACTION_NAME = "choose_actor_action"

# @api private
class Window_ActorCommand
  # alias_method :_neurosdk_setup, :setup
  alias_method :_neurosdk_activate, :activate
  alias_method :_neurosdk_call_ok_handler, :call_ok_handler

  # def setup(actor)
  def activate
    # _neurosdk_setup(actor)
    result = _neurosdk_activate
    return unless NeuroSDK.connected?
    return if NeuroSDK.forced?  # Prevent from firing twice
    return if @actor.nil?  # Prevent firing before @actor is set

    # TODO: Let Neuro control specific characters

    choice_action = NeuroAction.make_command_window_action(
      ACTOR_COMMAND_ACTION_NAME,
      "Choose an action for #{@actor.name}.",
      self
    )
    NeuroSDK.register_actions([choice_action])

    NeuroSDK.force_actions(
      [ACTOR_COMMAND_ACTION_NAME],
      "What should #{@actor.name} do?"
    )

    return result
  end

  def call_ok_handler
    _neurosdk_call_ok_handler
    return unless NeuroSDK.connected?

    NeuroSDK.unregister_actions([PARTY_COMMAND_ACTION_NAME])
  end
end

# TODO: Window_BattleStatus
# TODO: Window_BattleActor

# @api private
BATTLE_ENEMY_ACTION_NAME = "choose_target"

# @api private
class Window_BattleEnemy
  alias_method :_neurosdk_show, :show
  alias_method :_neurosdk_call_ok_handler, :call_ok_handler

  def show
    result = _neurosdk_show
    return result unless NeuroSDK.connected?

    choice_action = NeuroAction.make_selectable_window_action(
      BATTLE_ENEMY_ACTION_NAME,
      "Choose the target of the action.",
      self,
      $game_troop.alive_members.map(&:name)
    )
    NeuroSDK.register_actions([choice_action])

    # TODO: Query should depend on the actor and chosen action:
    #       "Who should <Neuro-sama|Evil Neuro|...> <attack|use the skill on|...>?"
    NeuroSDK.force_actions(
      [BATTLE_ENEMY_ACTION_NAME],
      "Choose the target of the action."
    )

    return result
  end

  def call_ok_handler
    _neurosdk_call_ok_handler
    return unless NeuroSDK.connected?

    NeuroSDK.unregister_actions([PARTY_COMMAND_ACTION_NAME])
  end
end

# @api private
BATTLE_SKILL_ACTION_NAME = "choose_skill"

# @api private
def format_skill(skill)
  line = "- #{skill.name} ("
  if skill.mp_cost > 0 || skill.tp_cost > 0
    line << "Costs "
    line << "#{skill.mp_cost} MP" if skill.mp_cost > 0
    line << ", " if skill.mp_cost > 0 && skill.tp_cost > 0
    line << "#{skill.tp_cost} TP" if skill.tp_cost > 0
  else
    line << "No cost"
  end
  line << "): "
  line << skill.description.gsub("\n", " ")
end

# @api private
class Window_BattleSkill
  alias_method :_neurosdk_activate, :activate
  alias_method :_neurosdk_call_ok_handler, :call_ok_handler

  def activate
    result = _neurosdk_activate
    return result unless NeuroSDK.connected?
    return result if NeuroSDK.forced?

    choice_action = NeuroAction.make_selectable_window_action(
      BATTLE_SKILL_ACTION_NAME,
      "Choose the skill you want to use.",
      self,
      @data.map { |skill| skill.name },
      (0...@data.size).select { |i| !enable?(@data[i]) }
    )
    NeuroSDK.register_actions([choice_action])

    valid_skills, invalid_skills = @data.partition { |skill| enable?(skill) }

    state = ""

    unless valid_skills.empty?
      state << "You can use the following skills:\n\n"
      state << valid_skills
        .map { |skill| format_skill(skill) }
        .join("\n")
    end

    state << "\n\n"

    unless invalid_skills.empty?
      state << "You cannot use the following skills due to unmet requirements:\n\n"
      state << invalid_skills
        .map { |skill| format_skill(skill) }
        .join("\n")
    end

    state.chomp!

    NeuroSDK.force_actions(
      [BATTLE_SKILL_ACTION_NAME],
      "Which skill do you want to use?",
      state
    )

    return result
  end

  def call_ok_handler
    _neurosdk_call_ok_handler
    return unless NeuroSDK.connected?

    NeuroSDK.unregister_actions([BATTLE_SKILL_ACTION_NAME])
  end
end

# @api private
BATTLE_ITEM_ACTION_NAME = "choose_item"

# @api private
class Window_BattleItem
  alias_method :_neurosdk_activate, :activate
  alias_method :_neurosdk_call_ok_handler, :call_ok_handler

  def activate
    result = _neurosdk_activate
    return result unless NeuroSDK.connected?
    return result if NeuroSDK.forced?

    choice_action = NeuroAction.make_selectable_window_action(
      BATTLE_ITEM_ACTION_NAME,
      "Choose the item you want to use.",
      self,
      @data.map { |item| item.name },
      (0...@data.size).select { |i| !enable?(@data[i]) }
    )
    NeuroSDK.register_actions([choice_action])

    # TODO: Item format and state

    NeuroSDK.force_actions(
      [BATTLE_ITEM_ACTION_NAME],
      "Which item do you want to use?"
    )

    return result
  end

  def call_ok_handler
    _neurosdk_call_ok_handler
    return unless NeuroSDK.connected?

    NeuroSDK.unregister_actions([BATTLE_ITEM_ACTION_NAME])
  end
end

# TODO: Window_TitleCommand
# TODO: Window_GameEnd
