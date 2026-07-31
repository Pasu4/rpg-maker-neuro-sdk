#==============================================================================
# RPG Maker VX Ace Basic Neuro Integration
#------------------------------------------------------------------------------
# Basic Neuro integration for RPG Maker.
# See https://github.com/Pasu4/rpg-maker-vxa-neuro-sdk for more information.
#
# Author: Pasu4
# Version: 0.1.0
#==============================================================================

###############################################################################
#                              CONFIGURATION                                  #
###############################################################################

# Whether Neuro can control the party command (Fight/Escape)
CAN_PARTY_COMMAND = true

###############################################################################
#                           END OF CONFIGURATION                              #
###############################################################################

class Window_Message
  alias_method :_neurosdk_process_all_text, :process_all_text

  def process_all_text
    # Send text to Neuro when it is printed on screen
    NeuroSDK.send_context($game_message.all_text) if NeuroSDK.connected?
    _neurosdk_process_all_text
  end
end

DIALOGUE_CHOICE_ACTION_NAME = "choose_dialogue_option"

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

PARTY_COMMAND_ACTION_NAME = "choose_party_action"

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

ACTOR_COMMAND_ACTION_NAME = "choose_actor_action"

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

BATTLE_ENEMY_ACTION_NAME = "choose_target"

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

BATTLE_SKILL_ACTION_NAME = "choose_skill"

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

BATTLE_ITEM_ACTION_NAME = "choose_item"

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
