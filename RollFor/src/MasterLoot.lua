---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.MasterLoot then return end

local M = {}
local _G = getfenv()
local pretty_print = modules.pretty_print
local hl = modules.colors.hl
local buttons_hooked = false
local original_toggle_dropdown_menu
local bypass_dropdown_menu = false

---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( master_loot_candidates, award_item, master_loot_frame, master_loot_tracker, config, loot_award_popup, master_loot_correlation_data )
  local m_confirmed = nil

  local function reset_confirmation()
    m_confirmed = nil
  end

  local function hook_toggle_dropdown_menu()
    original_toggle_dropdown_menu = modules.api.ToggleDropDownMenu

    _G[ "ToggleDropDownMenu" ] = function( level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList )
      if config.pfui_integration_enabled() and bypass_dropdown_menu then return end
      original_toggle_dropdown_menu( level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList )
    end
  end

  local function on_loot_slot_cleared( slot )
    if not m_confirmed then return end

    local item = master_loot_tracker.get( slot )

    if item then
      award_item( m_confirmed.player.name, item.id, item.link )
      master_loot_tracker.remove( slot )
    end

    reset_confirmation()
    master_loot_frame.hide()
  end

  local function on_confirm( player, item_link )
    local data = master_loot_correlation_data.get( item_link )
    if not data then return end
    m_confirmed = { slot = data.slot, player = player }
    modules.api.GiveMasterLoot( data.slot, player.value )
    master_loot_frame.hide()
  end

  local function normal_loot( button )
    reset_confirmation()
    button:OriginalOnClick()
  end

  local function show_loot_candidates_frame( slot, item_link, button )
    modules.api.LootFrame.selectedSlot = slot
    modules.api.LootFrame.selectedItemLink = item_link
    master_loot_correlation_data.set( item_link, slot )
    -- modules.api.LootFrame.selectedItemName = item_name

    modules.api.CloseDropDownMenus()
    master_loot_frame.create()
    master_loot_frame.hide()

    local candidates = master_loot_candidates.get()

    if getn( candidates ) == 0 then
      -- This happened before.
      modules.pretty_print( "Game API didn't return any loot candidates. Restoring original button hook." )
      normal_loot( button )
      return
    end

    master_loot_frame.create_candidate_frames( candidates, item_link )
    master_loot_frame.anchor( button )
    master_loot_frame.show( item_link )
  end

  local function on_loot_opened()
    if not modules.is_player_master_looter() then
      if buttons_hooked then
        master_loot_frame.restore_loot_buttons()
        buttons_hooked = false
      end

      return
    end

    reset_confirmation()

    if not original_toggle_dropdown_menu then hook_toggle_dropdown_menu() end
    bypass_dropdown_menu = true

    if modules.uses_pfui() and config.pfui_integration_enabled() then
      master_loot_frame.hook_pfui_loot_buttons( reset_confirmation, normal_loot, show_loot_candidates_frame, master_loot_frame.hide )
    else
      master_loot_frame.hook_loot_buttons( reset_confirmation, normal_loot, show_loot_candidates_frame, master_loot_frame.hide )
    end

    buttons_hooked = true
  end

  local function on_loot_closed()
    bypass_dropdown_menu = false
    master_loot_frame.hide()
    if not modules.is_player_master_looter() then return end

    local items_left_count = master_loot_tracker.count()

    if not m_confirmed then
      if items_left_count > 0 then pretty_print( "Not all items were distributed." ) end
      return
    end

    if items_left_count == 0 then
      return
    end

    local item = master_loot_tracker.get( m_confirmed.slot )

    if items_left_count > 1 then
      pretty_print( string.format( "%s (slot %s) was supposed to be given to %s.", item and item.link or "Item", m_confirmed.slot, m_confirmed.player.name ) )
      return
    end

    if item == nil then
      pretty_print( "A different slot left in the tracker.", "red" )
      return
    end

    award_item( m_confirmed.player.name, item.id, item.name, item.link )
    master_loot_tracker.remove( m_confirmed.slot )
    reset_confirmation()
  end

  local function on_recipient_inventory_full()
    if m_confirmed then
      pretty_print( string.format( "%s's inventory is full and cannot receive the item.", hl( m_confirmed.player.name ) ), "red" )
      reset_confirmation()
    end
  end

  local function on_player_is_too_far()
    if m_confirmed then
      pretty_print( string.format( "%s is too far to receive the item.", hl( m_confirmed.player.name ) ), "red" )
      reset_confirmation()
    end
  end

  local function on_unknown_error_message( message )
    if m_confirmed then
      if message ~= "You are too far away!" and message ~= "You must be in a raid group to enter this instance" then
        pretty_print( message, "red" )
      end

      reset_confirmation()
    end
  end

  loot_award_popup.register_confirm_callback( on_confirm )

  return {
    on_loot_slot_cleared = on_loot_slot_cleared,
    on_loot_opened = on_loot_opened,
    on_loot_closed = on_loot_closed,
    on_recipient_inventory_full = on_recipient_inventory_full,
    on_player_is_too_far = on_player_is_too_far,
    on_unknown_error_message = on_unknown_error_message
  }
end

modules.MasterLoot = M
return M
