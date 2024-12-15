---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.DroppedLoot then return end

local M = {}

local m = modules
---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( db )
  db.dropped_items = db.dropped_items or {}

  local function get_dropped_item_id( item_name )
    for _, item in pairs( db.dropped_items ) do
      if item.name == item_name then return item.id end
    end

    return nil
  end

  local function get_dropped_item_name( item_id )
    for _, item in pairs( db.dropped_items ) do
      if item.id == item_id then return item.name end
    end

    return nil
  end

  local function add( item_id, item_name )
    table.insert( db.dropped_items, { id = item_id, name = item_name } )
  end

  local function clear()
    if getn( db.dropped_items ) == 0 then return end
    m.clear_table( db.dropped_items )
  end

  return {
    get_dropped_item_id = get_dropped_item_id,
    get_dropped_item_name = get_dropped_item_name,
    add = add,
    clear = clear
  }
end

modules.DroppedLoot = M
return M
