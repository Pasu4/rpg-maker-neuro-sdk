# RPG Maker VX Ace Neuro SDK

Neuro SDK for [RPG Maker VX Ace](https://www.rpgmakerweb.com/products/rpg-maker-vx-ace).
All the main features of the API are implemented, however I'm still working on a general integration for basic RPGs.

## How to use

The SDK comes in two parts: Ruby scripts for RPG Maker and a proxy server that allows it to talk to the Neuro API.

To install the scripts into your game, open the script editor (F11), create scripts below `( Insert here )` and paste the content of the Ruby files there.
The order should be `RubyLibraryCode.rb`, `JSON.rb`, `NeuroSDK.rb`.
To connect to the Neuro API, add a script command containing `NeuroSDK.connect` to an event (currently does not work from the root fiber).
Note that the proxy server must be started at this point, otherwise the connection will fail.

<details><summary>Example</summary>

```ruby
# Activate the Neuro SDK
# Currently does not work from the root fiber
unless NeuroSDK.connect
  msgbox("Error: Could not connect to Neuro API.")
end

# Create an action
display_message_action = NeuroAction.new(
  "display_message",  # Action name
  "Display a message after some time.",  # Action description
  SchemaBuilder.object({  # Action schema
    text: SchemaBuilder.string
      .meta({ maxLength: 30 }),
    after: SchemaBuilder.integer
      .description("The time in frames (1/60 s) to wait before displaying the message.")
      .optional
      .min(0).max(300)
      .meta({ default: 0 })
  }),
  # Callback called when Neuro executes the action
  lambda { |data|
    text = data["text"]
    frames = data["after"]

    # There is no schema validation at the moment, so always check the types/constraints before use
    return NeuroActionResult.new(false, "'text' must be a string.") if text.nil? || !text.is_a?(String)
    return NeuroActionResult.new(false, "'text' must be at most 30 characters long.") if text.size > 30
    frames = 0 if frames.nil?
    return NeuroActionResult.new(false, "'after' must be an integer.") unless frames.is_a?(Integer)
    return NeuroActionResult.new(false, "'after' must be between 0 and 300") if frames < 0 || frames > 300

    # If you want to wait (i.e. yield), always use NeuroSDK.async
    NeuroSDK.async {
      frames.times { Fiber.yield }  # Wait for the specified amount of frames
      $game_message.add(text)  # Display the text
    }
    return NeuroActionResult.new true
  }
)

# Register the action
NeuroSDK.register_actions([display_message_action])

# Force the action
NeuroSDK.force_actions(
  [display_message_action.name],
  "You should send a message."
)
```

</details>

For the proxy server, run the JavaScript file using `node proxy-server.js`.
You can also build it to a standalone executable using `node --build-sea sea-config.json` (requires node >= v19.7.0 I believe).

All the main functionality of the API specification is implemented.
Additionally, Neuro will get context from dialogue boxes and can choose dialogue options.
The following is also planned in the future:
- Signifying the speaker in messages
- Equipping weapons/armor/etc.
- Using items from the inventory
- Buying/selling stuff at shops
- Walking / pathing to points of interest on the map

## Technical information

Since RPG Maker scripts cannot use packages, the SDK connects to the proxy server via a TCP socket.
However, since not even the standard library is included, the code for the socket has been included in `RubyLibraryCode.rb`.
I got this code from [a WordPress article](https://lthzelda.wordpress.com/2010/04/28/rm-4-tcp-sockets-in-rpg-maker-vx/), but apparently nobody knows where it actually came from (the links to the source are dead as well).

The SDK runs in a loop, constantly checking if there are new messages on the socket.
Since the buffer is continuous, messages are delimited by newline characters.

## Integration status

I didn't check what all of these do, some may be removed from this list if they're just base classes.

- [ ] Window_HorzCommand
- [ ] Window_Help
- [ ] Window_Gold
- [ ] Window_MenuCommand
- [ ] Window_MenuStatus
- [ ] Window_MenuActor
- [ ] Window_ItemCategory
- [ ] Window_ItemList
- [ ] Window_SkillCommand
- [ ] Window_SkillStatus
- [ ] Window_SkillList
- [ ] Window_EquipStatus
- [ ] Window_EquipCommand
- [ ] Window_EquipSlot
- [ ] Window_EquipItem
- [ ] Window_Status
- [ ] Window_SaveFile
- [ ] Window_ShopCommand
- [ ] Window_ShopBuy
- [ ] Window_ShopSell
- [ ] Window_ShopNumber
- [ ] Window_ShopStatus
- [ ] Window_NameEdit
- [ ] Window_NameInput
- [x] Window_ChoiceList
- [ ] Window_NumberInput
- [ ] Window_KeyItem
- [ ] Window_Message
    - [x] Get basic text
    - [ ] Fix escape sequences
    - [ ] Character name
- [ ] Window_ScrollText
- [ ] Window_MapName
- [x] Window_BattleLog
- [x] Window_PartyCommand
- [x] Window_ActorCommand
- [x] Window_BattleStatus
- [ ] Window_BattleActor
- [x] Window_BattleEnemy
- [x] Window_BattleSkill
- [x] Window_BattleItem
- [ ] Window_TitleCommand
- [ ] Window_GameEnd
