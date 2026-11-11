-- Andarilho: conta quanto o personagem já andou (yards, metros e km).
--
-- Como mede: a cada 0,2 s compara a posição atual com a anterior, mas só
-- enquanto o próprio jogador está se movendo (PLAYER_STARTED_MOVING), o que
-- descarta barco, zepelim e elevador. Correr contra a parede não muda a posição,
-- então não soma. Saltos maiores que a velocidade máxima possível (teleporte,
-- Blink, Charge) são descartados. O WoW Forever trata a velocidade do jogador
-- (GetUnitSpeed) como "secret value", então ela não é usada.
-- Em masmorras o jogo esconde a posição; ali a distância é estimada pela
-- velocidade base de cada tipo enquanto o jogador se move.
--
-- Cada dia fica guardado separado (char.days["AAAA-MM-DD"]) para o relatório.

local YARD_IN_METERS = 0.9144
local TICK = 0.2            -- segundos entre medições
local MAX_GAP = 1           -- intervalo maior que isso é tela de loading/travada

-- Velocidade máxima aceita (yd/s). Acima disso é teleporte e não conta.
local MAX_SPEED = { foot = 16, mount = 26, swim = 16 }
-- Velocidade estimada (yd/s) onde o jogo não informa a posição.
local ESTIMATED_SPEED = { foot = 7, mount = 14, swim = 4.72 }

local CATEGORIES = { "foot", "mount", "swim" }
local ROW_HEIGHT = 18
local DEFAULT_MINIMAP_ANGLE = 220

local STRINGS = {
  ptBR = {
    foot = "A pé", mount = "Montado", swim = "Nadando",
    session = "Sessão", today = "Hoje",
    thisChar = "Este personagem", allChars = "Todos os personagens",
    walked = "A pé (caminhada)",
    dragHint = "Arraste para mover.",
    minimize = "Minimizar",
    openReport = "Abrir o relatório",
    minimizedHint = "Andarilho minimizado. Clique no ícone do minimapa para abrir de novo.",
    minimizedHintNoIcon = "Andarilho minimizado. Digite /andarilho para abrir de novo.",
    minimapLeft = "Clique: mostrar/esconder a janela",
    minimapRight = "Botão direito: relatório",
    minimapDrag = "Arraste para mudar o ícone de lugar",
    reportTitle = "Andarilho · Relatório",
    days7 = "7 dias", days30 = "30 dias", allTime = "Tudo",
    searchHint = "Pesquisar (ex.: 12/11, 11/2026, sáb)",
    date = "Data",
    periodTotal = "Total a pé no período",
    average = "Média por dia",
    bestDay = "Melhor dia",
    daysListed = "Dias listados",
    noDays = "Nenhum dia encontrado.",
    historyNote = "O histórico por dia começa na versão 1.1.0.",
    language = "Idioma",
    langAuto = "Automático", langPt = "Português", langEn = "English",
    languageSet = "Idioma: %s.",
    languageUsage = "Use: /andarilho idioma auto | pt | en",
    minimapShown = "Ícone do minimapa visível.",
    minimapHidden = "Ícone do minimapa escondido. /andarilho minimapa para mostrar de novo.",
    help = "Comandos: /andarilho (mostra/esconde) · relatorio · total · idioma auto|pt|en · minimapa · trancar · centro · reset",
    locked = "Janela trancada.", unlocked = "Janela destrancada.",
    centered = "Janela de volta ao centro.",
    resetAsk = "Isso zera este personagem, inclusive o histórico. Para confirmar: /andarilho reset confirmar",
    resetDone = "Contagem deste personagem zerada.",
    weekdays = { "dom", "seg", "ter", "qua", "qui", "sex", "sáb" },
  },
  en = {
    foot = "On foot", mount = "Mounted", swim = "Swimming",
    session = "Session", today = "Today",
    thisChar = "This character", allChars = "All characters",
    walked = "On foot (walking)",
    dragHint = "Drag to move.",
    minimize = "Minimize",
    openReport = "Open the report",
    minimizedHint = "Andarilho minimized. Click the minimap icon to open it again.",
    minimizedHintNoIcon = "Andarilho minimized. Type /andarilho to open it again.",
    minimapLeft = "Click: show/hide the window",
    minimapRight = "Right-click: report",
    minimapDrag = "Drag to move the icon",
    reportTitle = "Andarilho · Report",
    days7 = "7 days", days30 = "30 days", allTime = "All",
    searchHint = "Search (e.g. 2026-11-12, 2026-11, Sat)",
    date = "Date",
    periodTotal = "Total on foot in period",
    average = "Daily average",
    bestDay = "Best day",
    daysListed = "Days listed",
    noDays = "No days found.",
    historyNote = "Daily history starts with version 1.1.0.",
    language = "Language",
    langAuto = "Automatic", langPt = "Português", langEn = "English",
    languageSet = "Language: %s.",
    languageUsage = "Use: /andarilho language auto | pt | en",
    minimapShown = "Minimap icon shown.",
    minimapHidden = "Minimap icon hidden. /andarilho minimap to show it again.",
    help = "Commands: /andarilho (show/hide) · report · total · language auto|pt|en · minimap · lock · center · reset",
    locked = "Window locked.", unlocked = "Window unlocked.",
    centered = "Window moved back to the center.",
    resetAsk = "This clears this character, including the history. To confirm: /andarilho reset confirm",
    resetDone = "This character's count was cleared.",
    weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" },
  },
}

local db, char
local L, DECIMAL, THOUSANDS
local session = { foot = 0, mount = 0, swim = 0 }
local lastX, lastY, lastInstance
local moving = false
local window, kmText, detailText, todayText
local minimapButton
local report, reportContent, reportEmpty, reportSummary, searchBox, scopeButton, languageButton
local reportRows, periodButtons = {}, {}
local reportState = { period = 7, scope = "char" }
local labels = {} -- textos fixos que mudam quando o idioma muda

-- Idioma ---------------------------------------------------------------------

local function LanguageCode()
  local choice = db and db.ui.lang or "auto"
  if choice == "pt" then return "ptBR" end
  if choice == "en" then return "en" end
  if GetLocale() == "ptBR" then return "ptBR" end
  return "en"
end

local function ResolveLanguage()
  local code = LanguageCode()
  L = STRINGS[code]
  if code == "ptBR" then
    DECIMAL, THOUSANDS = ",", "."
  else
    DECIMAL, THOUSANDS = ".", ","
  end
end
ResolveLanguage()

local function Label(widget, key)
  table.insert(labels, { widget = widget, key = key })
  widget:SetText(L[key])
end

local function LanguageName()
  local choice = db.ui.lang or "auto"
  if choice == "pt" then return L.langPt end
  if choice == "en" then return L.langEn end
  return L.langAuto
end

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
local function KmText(yards) return FormatNumber(Km(yards), 2) .. " km" end

local function FormatFull(yards)
  return FormatNumber(yards, 0) .. " yd · " .. FormatNumber(Meters(yards), 0)
    .. " m · " .. KmText(yards)
end

-- Dia da semana, 1 = domingo (método de Sakamoto).
local function Weekday(year, month, day)
  local offsets = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
  if month < 3 then year = year - 1 end
  return (year + math.floor(year / 4) - math.floor(year / 100)
    + math.floor(year / 400) + offsets[month] + day) % 7 + 1
end

local function FormatDay(key)
  local year, month, day = key:match("^(%d+)-(%d+)-(%d+)$")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  local weekday = L.weekdays[Weekday(year, month, day)]
  if LanguageCode() == "ptBR" then
    return string.format("%s %02d/%02d/%04d", weekday, day, month, year)
  end
  return string.format("%s %04d-%02d-%02d", weekday, year, month, day)
end

local function Today() return date("%Y-%m-%d") end

local function TodayFoot()
  local day = char.days[Today()]
  return day and day.foot or 0
end

-- Medição --------------------------------------------------------------------

local function ForgetPosition()
  lastX, lastY, lastInstance = nil, nil, nil
end

-- Valores que o jogo marca como secretos não podem ser comparados nem somados.
local function Usable(...)
  if not issecretvalue then return true end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then return false end
  end
  return true
end

-- Yards andados desde a última medição.
local function Measure(dt, category)
  local y, x, _, instance = UnitPosition("player")
  if not Usable(x, y, instance) then x, y, instance = nil, nil, nil end
  local prevX, prevY, prevInstance = lastX, lastY, lastInstance
  lastX, lastY, lastInstance = x, y, instance

  if not moving then return 0 end -- barco, elevador e zepelim movem sem andar
  if not x then return ESTIMATED_SPEED[category] * dt end -- masmorra
  if not prevX or prevInstance ~= instance then return 0 end

  local dx, dy = x - prevX, y - prevY
  local moved = math.sqrt(dx * dx + dy * dy)
  if moved > MAX_SPEED[category] * dt then return 0 end -- teleporte
  return moved
end

local function Flag(fn, ...)
  if not fn then return false end
  local value = fn(...)
  return Usable(value) and value and true or false
end

local function CurrentCategory()
  if Flag(UnitOnTaxi, "player") then return nil end
  if Flag(UnitInVehicle, "player") then return nil end
  if Flag(IsSwimming) then return "swim" end
  if Flag(IsMounted) then return "mount" end
  return "foot"
end

local function Tick(dt)
  if dt > MAX_GAP then ForgetPosition(); return end
  local category = CurrentCategory()
  if not category then ForgetPosition(); return end
  local yards = Measure(dt, category)
  if yards <= 0 then return end

  char[category] = (char[category] or 0) + yards
  session[category] = session[category] + yards
  local key = Today()
  local day = char.days[key]
  if not day then
    day = { foot = 0, mount = 0, swim = 0 }
    char.days[key] = day
  end
  day[category] = day[category] + yards
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

-- Mensagens ------------------------------------------------------------------

local function Say(text)
  print("|cff33cc66Andarilho|r: " .. text)
end

-- Janela principal -----------------------------------------------------------

local function Refresh()
  if not window or not window:IsShown() then return end
  kmText:SetText(KmText(char.foot))
  detailText:SetText(FormatNumber(char.foot, 0) .. " yd · "
    .. FormatNumber(Meters(char.foot), 0) .. " m")
  todayText:SetText(L.today .. ": " .. KmText(TodayFoot()) .. "   "
    .. L.session .. ": " .. KmText(session.foot))
end

local function SetWindowShown(shown, fromMinimize)
  db.ui.shown = shown
  window:SetShown(shown)
  Refresh()
  if fromMinimize and not db.ui.minimizeHintShown then
    db.ui.minimizeHintShown = true
    Say(db.ui.minimapHidden and L.minimizedHintNoIcon or L.minimizedHint)
  end
end

local function ToggleWindow()
  SetWindowShown(not window:IsShown())
end

local function ShowWindowTooltip(self)
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

local function SimpleTooltip(owner, key)
  owner:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L[key])
    GameTooltip:Show()
  end)
  owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
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

local function ApplyBackdrop(frame)
  if not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.8)
  frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
end

local ToggleReport, ApplyLanguage -- definidas mais abaixo

local function BuildWindow()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  window = CreateFrame("Frame", "AndarilhoFrame", UIParent, template)
  window:SetSize(196, 80)
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
  window:SetScript("OnEnter", ShowWindowTooltip)
  window:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ApplyBackdrop(window)

  local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOP", 0, -7)
  Label(title, "walked")

  kmText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  kmText:SetPoint("TOP", title, "BOTTOM", 0, -2)

  detailText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  detailText:SetPoint("TOP", kmText, "BOTTOM", 0, -2)

  todayText = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  todayText:SetPoint("TOP", detailText, "BOTTOM", 0, -3)

  local minimize = CreateFrame("Button", "AndarilhoMinimizeButton", window)
  minimize:SetSize(14, 14)
  minimize:SetPoint("TOPRIGHT", -5, -5)
  minimize:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
  minimize:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
  minimize:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
  minimize:SetScript("OnClick", function() SetWindowShown(false, true) end)
  SimpleTooltip(minimize, "minimize")

  local reportButton = CreateFrame("Button", "AndarilhoReportButton", window)
  reportButton:SetSize(14, 14)
  reportButton:SetPoint("TOPLEFT", 5, -5)
  reportButton:SetNormalTexture("Interface\\Icons\\INV_Misc_Note_01")
  reportButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  reportButton:SetScript("OnClick", function() ToggleReport() end)
  SimpleTooltip(reportButton, "openReport")

  ApplyPosition()
  window:SetShown(db.ui.shown ~= false)
end

-- Ícone no minimapa ----------------------------------------------------------

local function UpdateMinimapPosition()
  local angle = math.rad(db.ui.minimapAngle or DEFAULT_MINIMAP_ANGLE)
  local radius = (Minimap:GetWidth() / 2) + 5
  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER",
    math.cos(angle) * radius, math.sin(angle) * radius)
end

local function FollowCursor()
  local centerX, centerY = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cursorX, cursorY = GetCursorPosition()
  cursorX, cursorY = cursorX / scale, cursorY / scale
  db.ui.minimapAngle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
  UpdateMinimapPosition()
end

local function ShowMinimapTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("Andarilho", 0.2, 0.8, 0.4)
  GameTooltip:AddDoubleLine(L.today, KmText(TodayFoot()), 1, 0.82, 0, 1, 1, 1)
  GameTooltip:AddDoubleLine(L.session, KmText(session.foot), 1, 0.82, 0, 1, 1, 1)
  GameTooltip:AddDoubleLine(L.thisChar, KmText(char.foot), 1, 0.82, 0, 1, 1, 1)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L.minimapLeft, 0.7, 0.7, 0.7)
  GameTooltip:AddLine(L.minimapRight, 0.7, 0.7, 0.7)
  GameTooltip:AddLine(L.minimapDrag, 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

local function BuildMinimapButton()
  local button = CreateFrame("Button", "AndarilhoMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetPoint("TOPLEFT", 7, -5)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  icon:SetPoint("TOPLEFT", 7, -6)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      ToggleReport()
    else
      ToggleWindow()
    end
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", FollowCursor)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", ShowMinimapTooltip)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  minimapButton = button
  UpdateMinimapPosition()
  button:SetShown(not db.ui.minimapHidden)
end

-- Relatório ------------------------------------------------------------------

local function Trim(text)
  return (text or ""):match("^%s*(.-)%s*$")
end

local function CollectDays()
  local sources = { char }
  if reportState.scope == "all" then
    sources = {}
    for _, data in pairs(db.chars) do table.insert(sources, data) end
  end

  local merged = {}
  for _, data in ipairs(sources) do
    for key, day in pairs(data.days or {}) do
      local entry = merged[key]
      if not entry then
        entry = { foot = 0, mount = 0, swim = 0 }
        merged[key] = entry
      end
      for _, category in ipairs(CATEGORIES) do
        entry[category] = entry[category] + (day[category] or 0)
      end
    end
  end

  local cutoff
  if reportState.period > 0 then
    cutoff = date("%Y-%m-%d", time() - (reportState.period - 1) * 86400)
  end
  local search = Trim(searchBox and searchBox:GetText()):lower()

  local list = {}
  for key, data in pairs(merged) do
    if not cutoff or key >= cutoff then
      local label = FormatDay(key)
      if search == "" or label:lower():find(search, 1, true) or key:find(search, 1, true) then
        table.insert(list, { key = key, label = label, data = data })
      end
    end
  end
  table.sort(list, function(a, b) return a.key > b.key end)
  return list
end

local COLUMNS = { { "date", 8, 112 }, { "foot", 124, 64 }, { "mount", 192, 64 }, { "swim", 260, 64 } }

local function CreateRow(index)
  local row = CreateFrame("Frame", nil, reportContent)
  row:SetSize(330, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
  if index % 2 == 0 then
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, 0.05)
  end
  row.cells = {}
  for i, column in ipairs(COLUMNS) do
    local cell = row:CreateFontString(nil, "OVERLAY",
      i == 1 and "GameFontHighlightSmall" or "GameFontNormalSmall")
    cell:SetPoint("LEFT", column[2], 0)
    cell:SetWidth(column[3])
    cell:SetJustifyH(i == 1 and "LEFT" or "RIGHT")
    row.cells[column[1]] = cell
  end
  reportRows[index] = row
  return row
end

local function UpdateReportControls()
  for _, info in ipairs(periodButtons) do
    if info.days == reportState.period then
      info.button:LockHighlight()
    else
      info.button:UnlockHighlight()
    end
  end
  scopeButton:SetText(reportState.scope == "all" and L.allChars or L.thisChar)
  languageButton:SetText(L.language .. ": " .. LanguageName())
end

local function RefreshReport()
  if not report or not report:IsShown() then return end
  local list = CollectDays()
  local total, best = 0, nil
  for index, entry in ipairs(list) do
    total = total + entry.data.foot
    if not best or entry.data.foot > best.data.foot then best = entry end
    local row = reportRows[index] or CreateRow(index)
    row.cells.date:SetText(entry.label)
    for _, category in ipairs(CATEGORIES) do
      row.cells[category]:SetText(KmText(entry.data[category]))
    end
    row:Show()
  end
  for index = #list + 1, #reportRows do reportRows[index]:Hide() end
  reportContent:SetHeight(math.max(ROW_HEIGHT, #list * ROW_HEIGHT))
  reportEmpty:SetShown(#list == 0)

  local average = #list > 0 and total / #list or 0
  local lines = {
    L.periodTotal .. ": |cffffffff" .. KmText(total) .. "|r",
    L.average .. ": |cffffffff" .. KmText(average) .. "|r   "
      .. L.daysListed .. ": |cffffffff" .. #list .. "|r",
  }
  if best then
    table.insert(lines, L.bestDay .. ": |cffffffff" .. best.label .. " · "
      .. KmText(best.data.foot) .. "|r")
  end
  reportSummary:SetText(table.concat(lines, "\n"))
  UpdateReportControls()
end

local function MakeButton(parent, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetScript("OnClick", onClick)
  return button
end

local function BuildReport()
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  report = CreateFrame("Frame", "AndarilhoReport", UIParent, template)
  report:SetSize(384, 440)
  report:SetPoint("CENTER")
  report:SetFrameStrata("DIALOG")
  report:SetClampedToScreen(true)
  report:SetMovable(true)
  report:EnableMouse(true)
  report:RegisterForDrag("LeftButton")
  report:SetScript("OnDragStart", report.StartMoving)
  report:SetScript("OnDragStop", report.StopMovingOrSizing)
  report:SetScript("OnShow", RefreshReport)
  ApplyBackdrop(report)
  report:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "AndarilhoReport") end -- ESC fecha

  local title = report:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -12)
  Label(title, "reportTitle")

  local close = CreateFrame("Button", nil, report, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)

  -- Período e escopo
  local previous
  for _, info in ipairs({ { days = 7, key = "days7" }, { days = 30, key = "days30" },
      { days = 0, key = "allTime" } }) do
    local button = MakeButton(report, 66, function()
      reportState.period = info.days
      RefreshReport()
    end)
    if previous then
      button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    else
      button:SetPoint("TOPLEFT", 14, -36)
    end
    Label(button, info.key)
    table.insert(periodButtons, { days = info.days, button = button })
    previous = button
  end

  scopeButton = MakeButton(report, 140, function()
    reportState.scope = reportState.scope == "all" and "char" or "all"
    RefreshReport()
  end)
  scopeButton:SetPoint("TOPRIGHT", -14, -36)

  -- Pesquisa
  searchBox = CreateFrame("EditBox", "AndarilhoReportSearch", report, "InputBoxTemplate")
  searchBox:SetSize(346, 20)
  searchBox:SetPoint("TOPLEFT", 22, -66)
  searchBox:SetAutoFocus(false)
  local placeholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  placeholder:SetPoint("LEFT", 2, 0)
  Label(placeholder, "searchHint")
  searchBox:SetScript("OnTextChanged", function(self)
    placeholder:SetShown(self:GetText() == "")
    RefreshReport()
  end)
  searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  -- Resumo
  reportSummary = report:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  reportSummary:SetPoint("TOPLEFT", 16, -96)
  reportSummary:SetJustifyH("LEFT")
  reportSummary:SetSpacing(3)

  -- Cabeçalho da tabela
  for i, column in ipairs(COLUMNS) do
    local header = report:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", 14 + column[2], -148)
    header:SetWidth(column[3])
    header:SetJustifyH(i == 1 and "LEFT" or "RIGHT")
    Label(header, column[1])
  end

  local scroll = CreateFrame("ScrollFrame", "AndarilhoReportScroll", report,
    "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -164)
  scroll:SetPoint("BOTTOMRIGHT", -32, 44)
  reportContent = CreateFrame("Frame", nil, scroll)
  reportContent:SetSize(330, ROW_HEIGHT)
  scroll:SetScrollChild(reportContent)

  reportEmpty = report:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  reportEmpty:SetPoint("TOP", scroll, "TOP", 10, -20)
  Label(reportEmpty, "noDays")

  -- Rodapé
  languageButton = MakeButton(report, 170, function()
    local order = { auto = "pt", pt = "en", en = "auto" }
    db.ui.lang = order[db.ui.lang or "auto"]
    ApplyLanguage()
  end)
  languageButton:SetPoint("BOTTOMLEFT", 14, 12)

  local note = report:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("BOTTOMRIGHT", -16, 18)
  note:SetWidth(180)
  note:SetJustifyH("RIGHT")
  Label(note, "historyNote")
end

ToggleReport = function()
  report:SetShown(not report:IsShown())
end

-- Aplica o idioma escolhido em todos os textos já criados.
ApplyLanguage = function()
  ResolveLanguage()
  for _, item in ipairs(labels) do item.widget:SetText(L[item.key]) end
  Refresh()
  RefreshReport()
end

-- Comandos -------------------------------------------------------------------

local function PrintTotals()
  for _, category in ipairs(CATEGORIES) do
    Say(L[category] .. ": " .. FormatFull(char[category]))
  end
  Say(L.today .. " (" .. L.foot .. "): " .. FormatFull(TodayFoot()))
  Say(L.session .. " (" .. L.foot .. "): " .. FormatFull(session.foot))
  Say(L.allChars .. " (" .. L.foot .. "): " .. FormatFull(AllCharsTotal().foot))
end

local function ResetCharacter()
  for _, category in ipairs(CATEGORIES) do
    char[category] = 0
    session[category] = 0
  end
  char.days = {}
  Say(L.resetDone)
  Refresh()
  RefreshReport()
end

local function SetLanguage(argument)
  local choices = { auto = "auto", pt = "pt", ptbr = "pt", portugues = "pt",
    ["português"] = "pt", en = "en", english = "en", ingles = "en", ["inglês"] = "en" }
  local choice = choices[argument]
  if not choice then
    Say(string.format(L.languageSet, LanguageName()) .. " " .. L.languageUsage)
    return
  end
  db.ui.lang = choice
  ApplyLanguage()
  Say(string.format(L.languageSet, LanguageName()))
end

local function ToggleMinimapButton()
  db.ui.minimapHidden = not db.ui.minimapHidden
  minimapButton:SetShown(not db.ui.minimapHidden)
  Say(db.ui.minimapHidden and L.minimapHidden or L.minimapShown)
end

SLASH_ANDARILHO1 = "/andarilho"
SlashCmdList.ANDARILHO = function(message)
  local command, argument = (message or ""):lower():match("^%s*(%S*)%s*(%S*)")
  if command == "" then
    ToggleWindow()
  elseif command == "relatorio" or command == "relatório" or command == "report" then
    ToggleReport()
  elseif command == "total" then
    PrintTotals()
  elseif command == "idioma" or command == "language" or command == "lang" then
    SetLanguage(argument)
  elseif command == "minimapa" or command == "minimap" then
    ToggleMinimapButton()
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
  if refreshElapsed >= 1 then
    Refresh()
    RefreshReport()
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
  char.days = char.days or {}

  ResolveLanguage()
  BuildWindow()
  BuildMinimapButton()
  BuildReport()
  Refresh()
  driver:SetScript("OnUpdate", OnUpdate)
end

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_STARTED_MOVING")
driver:RegisterEvent("PLAYER_STOPPED_MOVING")
driver:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    Initialize()
  elseif event == "PLAYER_STARTED_MOVING" then
    moving = true
  elseif event == "PLAYER_STOPPED_MOVING" then
    moving = false
  else
    moving = Flag(IsPlayerMoving)
    ForgetPosition()
  end
end)
