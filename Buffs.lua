local _, addon = ...

-- Canonical Classic Era world buffs, one entry per grid column.
--
-- Each column carries a `variants` list — usually one spellID/name pair,
-- but mutually-exclusive buffs that share a slot (the seven Sayge's Dark
-- Fortune flavours) collapse into a single column with multiple variants.
--
-- duration is the full duration in seconds, used by the UI to render a
-- proportional bar. The game's expirationTime is authoritative for the
-- countdown — duration is only the denominator.
--
-- shortName is what the cross-character grid header shows; keeping it
-- under ~8 chars keeps the table compact on alts with many buffs.
addon.WORLD_BUFFS = {
  { shortName = "Dragonslayer", icon = 134153, duration = 2 * 3600, variants = {
      { id = 22888, name = "Rallying Cry of the Dragonslayer" },
  }},
  { shortName = "Hakkar",       icon = 132107, duration = 2 * 3600, variants = {
      { id = 24425, name = "Spirit of Zandalar" },
  }},
  { shortName = "Songflower",   icon = 135934, duration = 1 * 3600, variants = {
      { id = 15366, name = "Songflower Serenade" },
  }},
  { shortName = "Rend",         icon = "Interface\\Icons\\Spell_Arcane_TeleportOrgrimmar", duration = 1 * 3600, variants = {
      { id = 16609, name = "Warchief's Blessing" },
  }},
  { shortName = "Slip'kik",     icon = 135930, duration = 2 * 3600, variants = {
      { id = 22820, name = "Slip'kik's Savvy" },
  }},
  { shortName = "Fengus",       icon = 136109, duration = 2 * 3600, variants = {
      { id = 22817, name = "Fengus' Ferocity" },
  }},
  { shortName = "Mol'dar",      icon = 136054, duration = 2 * 3600, variants = {
      { id = 22818, name = "Mol'dar's Moxie" },
  }},
  { shortName = "DMF",          icon = 134334, duration = 2 * 3600, variants = {
      { id = 23768, name = "Sayge's Dark Fortune of Damage" },
      { id = 23736, name = "Sayge's Dark Fortune of Agility" },
      { id = 23766, name = "Sayge's Dark Fortune of Intellect" },
      { id = 23737, name = "Sayge's Dark Fortune of Stamina" },
      { id = 23735, name = "Sayge's Dark Fortune of Strength" },
      { id = 23769, name = "Sayge's Dark Fortune of Spirit" },
      { id = 23767, name = "Sayge's Dark Fortune of Armor" },
  }},
}

-- Faction-aware column ordering. Warchief's Blessing (Rend) is Horde-only,
-- so on Alliance it lives at the end as a low-priority slot and on Horde it
-- moves to the front. The base WORLD_BUFFS table is the canonical list;
-- callers should use this to drive the UI.
function addon:GetOrderedBuffs(faction)
  local rend, others = nil, {}
  for _, b in ipairs(self.WORLD_BUFFS) do
    if b.shortName == "Rend" then rend = b
    else others[#others + 1] = b end
  end
  if not rend then return others end
  local out = {}
  if faction == "Horde" then
    out[#out + 1] = rend
    for _, b in ipairs(others) do out[#out + 1] = b end
  else
    for _, b in ipairs(others) do out[#out + 1] = b end
    out[#out + 1] = rend
  end
  return out
end

-- The Supercharged Chronoboon Displacer item (184937) applies aura 349981,
-- which itself is a meta-buff carrying the saved world buffs. We track it
-- separately so the UI can show "boons stored" alongside the live grid.
addon.CHRONOBOON_SPELL_ID = 349981
addon.CHRONOBOON_ITEM_ID  = 184937

-- Lookup: variant spellID -> column entry. Built lazily.
local byID
function addon:GetWorldBuff(spellID)
  if not byID then
    byID = {}
    for _, col in ipairs(addon.WORLD_BUFFS) do
      for _, v in ipairs(col.variants) do
        byID[v.id] = col
      end
    end
  end
  return byID[spellID]
end

-- Lookup: variant name -> column entry. Used by the chronoboon tooltip
-- parser to recognise stored buffs from their printed names.
local byName
function addon:GetWorldBuffByName(name)
  if not name then return nil end
  if not byName then
    byName = {}
    for _, col in ipairs(addon.WORLD_BUFFS) do
      for _, v in ipairs(col.variants) do
        byName[v.name] = col
      end
    end
  end
  return byName[name]
end

-- Returns the snapshot entry from `buffs` (or chronoboon contents) for
-- whichever variant of `col` is present, or nil if none are. Centralises
-- the variants iteration that the UI needs for every cell.
function addon:VariantSnap(buffs, col)
  if not buffs or not col then return nil end
  for _, v in ipairs(col.variants) do
    local snap = buffs[v.id]
    if snap then return snap end
  end
  return nil
end
