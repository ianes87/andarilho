-- Andarilho: conta quanto o personagem já andou (yards, metros e km).
--
-- Como mede: a cada 0,2 s compara a posição atual com a anterior. A velocidade
-- do jogo serve de limite, o que descarta teleporte e correr parado contra a
-- parede. Em masmorras o jogo esconde a posição; ali usa velocidade x tempo.

local YARD_IN_METERS = 0.9144
local TICK = 0.2            -- segundos entre medições
local MAX_GAP = 1           -- intervalo maior que isso é tela de loading/travada
local SPEED_TOLERANCE = 1.25 -- folga sobre a velocidade informada pelo jogo

local CATEGORIES = { "foot", "mount", "swim" }

local STRINGS = {
  ptBR = {
    foot = "A pé", mount = "Montado", swim = "Nadando",
    session = "Sessão", thisChar = "Este personagem", allChars = "Todos os personagens",
    walked = "A pé (caminhada)",
    dragHint = "Arraste para mover. /andarilho para os comandos.",
    help = "Comandos: /andarilho (mostra/esconde) · total · trancar · centro · reset",
    locked = "Janela trancada.", unlocked = "Janela destrancada.",
    centered = "Janela de volta ao centro.",
    resetAsk = "Isso zera este personagem. Para confirmar: /andarilho reset confirmar",
    resetDone = "Contagem deste personagem zerada.",
  },
  en = {
    foot = "On foot", mount = "Mounted", swim = "Swimming",
    session = "Session", thisChar = "This character", allChars = "All characters",
    walked = "On foot (walking)",
    dragHint = "Drag to move. /andarilho for commands.",
    help = "Commands: /andarilho (show/hide) · total · lock · center · reset",
    locked = "Window locked.", unlocked = "Window unlocked.",
    centered = "Window moved back to the center.",
    resetAsk = "This clears this character. To confirm: /andarilho reset confirm",
    resetDone = "This character's count was cleared.",
  },
}
local L = STRINGS[GetLocale()] or STRINGS.en
local DECIMAL, THOUSANDS = ",", "."
if GetLocale() ~= "ptBR" then DECIMAL, THOUSANDS = ".", "," end

local db, char
local session = { foot = 0, mount = 0, swim = 0 }
local lastX, lastY, lastInstance
local window, kmText, detailText, sessionText

-- Formatação -----------------------------------------------------------------

local function FormatNumber(value, decimals)
  local text = string.format("%." .. decimals .. "f", value)
  local whole, fraction = text:match("^(%d+)%.?(%d*)$")
  whole = whole:reverse():gsub("(%d%d%d)", "%1" .. THOUSANDS):reverse()
  if whole:sub(1, 1) == THOUSANDS then whole = whole:sub(2) end
  if fraction ~= "" then return whole .. DECIMAL .. fraction end
  return whole
end

local function Meters(yards) return yards * YARD_IN_METERS end
local function Km(yards) return Meters(yards) / 1000 end

local function FormatFull(yards)
  return FormatNumber(yards, 0) .. " yd · " .. FormatNumber(Meters(yards), 0)
    .. " m · " .. FormatNumber(Km(yards), 2) .. " km"
end

local function Sum(t)
  return (t.foot or 0) + (t.mount or 0) + (t.swim or 0)
end

-- Medição --------------------------------------------------------------------

local function ForgetPosition()
  lastX, lastY, lastInstance = nil, nil, nil
end

-- Yards andados desde a última medição.
local function Measure(dt)
  local speed = GetUnitSpeed("player") or 0
  local y, x, _, instance = UnitPosition("player")
  local prevX, prevY, prevInstance = lastX, lastY, lastInstance
  lastX, lastY, lastInstance = x, y, instance

  if speed <= 0 then return 0 end -- barco, elevador e zepelim movem sem andar
  local limit = speed * dt
  if not x then return limit end  -- masmorra: posição indisponível
  if not prevX or prevInstance ~= instance then return 0 end

  local dx, dy = x - prevX, y - prevY
  local moved = math.sqrt(dx * dx + dy * dy)
  return math.min(moved, limit * SPEED_TOLERANCE)
end

local function CurrentCategory()
  if UnitOnTaxi("player") then return nil end
  if UnitInVehicle and UnitInVehicle("player") then return nil end
  if IsSwimming() then return "swim" end
  if IsMounted() then return "mount" end
  return "foot"
end

local function Tick(dt)
  if dt > MAX_GAP then ForgetPosition(); return end
  local category = CurrentCategory()
  if not category then ForgetPosition(); return end
  local yards = Measure(dt)
  if yards > 0 then
    char[category] = (char[category] or 0) + yards
    session[category] = session[category] + yards
  end
end

-- Janela ---------------------------------------------------------------------

local function Refresh()
  if not window or not window:IsShown() then return end
  kmText:SetText(FormatNumber(Km(char.foot), 2) .. " km")
  detailText:SetText(FormatNumber(char.foot, 0) .. " yd · "
    .. FormatNumber(Meters(char.foot), 0) .. " m")
  sessionText:SetText(L.session .. ": " .. FormatNumber(Km(session.foot), 2) .. " km")
end

local function AllCharsTotal()
  local total = { foot = 0, mount = 0, swim = 0 }
  for _, data in pairs(db.chars) do
    for _, category in ipairs(CATEGORIES) do
      total[category] = total[category] + (data[category] or 0)
    end
  end
  return total
end

local function ShowTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:AddLine("Andarilho", 0.2, 0.8, 0.4)
  GameTooltip:AddLine(L.thisChar, 1, 0.82, 0)
  for _, category in ipairs(CATEGORIES) do
    GameTooltip:AddDoubleLine(L[category], FormatFull(char[category]), 1, 1, 1, 1, 1, 1)
  end
  local total = AllCharsTotal()
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L.allChars, 1, 0.82, 0)
  for _, category in ipairs(CATEGORIES) do
    GameTooltip:AddDoubleLine(L[category], FormatFull(total[category]), 1, 1, 1, 1, 1, 1)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L.dragHint, 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

local function SavePosition()
  local point, _, relativePoint, x, y = window:GetPoint()
  db.ui.point, db.ui.relativePoint, db.ui.x, db.ui.y = point, relativePoint, x, y
end

local function ApplyPosition()
  window:ClearAllPoints()
  window:SetPoint(db.ui.point or "CENTER", UIParent, db.ui.relativePoint or "CENTER",
    db.ui.x or 0, db.ui.y or 200)
end

local function BuildWindow()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  window = CreateFrame("Frame", "AndarilhoFrame", UIParent, template)
  window:SetSize(170, 72)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", function(self)
    if not db.ui.locked then self:StartMoving() end
  end)
  window:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
  end)
  window:SetScript("OnEnter", ShowTooltip)
  window:SetScript("OnLeave", function() GameTooltip:Hide() end)
  if window.SetBackdrop then
    window:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    window:SetBackdropColor(0, 0, 0, 0.7)
    window:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
  end

  local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOP", 0, -7)
  title:SetText(L.walked)

  kmText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  kmText:SetPoint("TOP", title, "BOTTOM", 0, -2)

  detailText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  detailText:SetPoint("TOP", kmText, "BOTTOM", 0, -2)

  sessionText = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sessionText:SetPoint("TOP", detailText, "BOTTOM", 0, -1)

  ApplyPosition()
  window:SetShown(db.ui.shown ~= false)
end

-- Comandos -------------------------------------------------------------------

local function Say(text)
  print("|cff33cc66Andarilho|r: " .. text)
end

local function PrintTotals()
  for _, category in ipairs(CATEGORIES) do
    Say(L[category] .. ": " .. FormatFull(char[category]))
  end
  Say(L.session .. " (" .. L.foot .. "): " .. FormatFull(session.foot))
  Say(L.allChars .. " (" .. L.foot .. "): " .. FormatFull(AllCharsTotal().foot))
end

local function ResetCharacter()
  for _, category in ipairs(CATEGORIES) do
    char[category] = 0
    session[category] = 0
  end
  Say(L.resetDone)
  Refresh()
end

SLASH_ANDARILHO1 = "/andarilho"
SlashCmdList.ANDARILHO = function(message)
  local command, argument = (message or ""):lower():match("^%s*(%S*)%s*(%S*)")
  if command == "" then
    db.ui.shown = not window:IsShown()
    window:SetShown(db.ui.shown)
    Refresh()
  elseif command == "total" then
    PrintTotals()
  elseif command == "trancar" or command == "lock" then
    db.ui.locked = not db.ui.locked
    Say(db.ui.locked and L.locked or L.unlocked)
  elseif command == "centro" or command == "center" then
    db.ui.point, db.ui.relativePoint, db.ui.x, db.ui.y = nil, nil, nil, nil
    ApplyPosition()
    Say(L.centered)
  elseif command == "reset" then
    if argument == "confirmar" or argument == "confirm" then
      ResetCharacter()
    else
      Say(L.resetAsk)
    end
  else
    Say(L.help)
  end
end

-- Inicialização --------------------------------------------------------------

local driver = CreateFrame("Frame")
local tickElapsed, refreshElapsed = 0, 0

local function OnUpdate(_, elapsed)
  tickElapsed = tickElapsed + elapsed
  refreshElapsed = refreshElapsed + elapsed
  if tickElapsed >= TICK then
    Tick(tickElapsed)
    tickElapsed = 0
  end
  if refreshElapsed >= 0.5 then
    Refresh()
    refreshElapsed = 0
  end
end

local function Initialize()
  AndarilhoDB = AndarilhoDB or {}
  db = AndarilhoDB
  db.chars = db.chars or {}
  db.ui = db.ui or {}

  local key = UnitName("player") .. "-" .. GetRealmName()
  db.chars[key] = db.chars[key] or {}
  char = db.chars[key]
  for _, category in ipairs(CATEGORIES) do
    char[category] = char[category] or 0
  end

  BuildWindow()
  Refresh()
  driver:SetScript("OnUpdate", OnUpdate)
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    Initialize()
  else
    ForgetPosition()
  end
end)
