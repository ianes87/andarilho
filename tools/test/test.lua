-- Teste do Andarilho fora do jogo, com a API do WoW simulada.
-- Uso: lua5.1 tools/test/test.lua Andarilho/Andarilho.lua

local frames, state = {}, nil
local function resetState()
  state = { speed = 0, x = 0, y = 0, inst = 0, taxi = false, swim = false,
    mount = false, vehicle = false }
end
resetState()

-- Objeto genérico de UI: guarda texto, visibilidade e scripts; o resto não faz nada.
local methods = {
  SetText = function(s, v) rawset(s, "text", v) end,
  GetText = function(s) return rawget(s, "text") or "" end,
  SetScript = function(s, n, f) local sc = rawget(s, "scripts") or {}; rawset(s, "scripts", sc); sc[n] = f end,
  IsShown = function(s) return rawget(s, "shown") ~= false end,
  SetShown = function(s, v)
    local was = rawget(s, "shown") ~= false
    rawset(s, "shown", v and true or false)
    local sc = rawget(s, "scripts")
    if v and not was and sc and sc.OnShow then sc.OnShow(s) end
  end,
  Show = function(s) rawset(s, "shown", true); local sc = rawget(s, "scripts"); if sc and sc.OnShow then sc.OnShow(s) end end,
  Hide = function(s) rawset(s, "shown", false) end,
  GetPoint = function() return "TOP", nil, "TOP", 1, 2 end,
  GetWidth = function() return 140 end,
  GetCenter = function() return 100, 100 end,
  GetEffectiveScale = function() return 1 end,
  LockHighlight = function(s) rawset(s, "locked", true) end,
  UnlockHighlight = function(s) rawset(s, "locked", false) end,
}
local newObj
local function track(o) table.insert(frames, o); return o end
newObj = function()
  return setmetatable({}, { __index = function(_, k)
    if methods[k] then return methods[k] end
    if k == "CreateFontString" or k == "CreateTexture" then return function() return track(newObj()) end end
    return function() end
  end })
end

function GetLocale() return state.locale or "ptBR" end
function CreateFrame(_, name)
  local f = track(newObj())
  if name then _G[name] = f end
  return f
end
UIParent, GameTooltip, Minimap = newObj(), newObj(), newObj()
BackdropTemplateMixin, UISpecialFrames, SlashCmdList = {}, {}, {}
local printed = {}
function print(s) table.insert(printed, s) end
local SECRET = setmetatable({}, {
  __lt = function() error("attempt to compare a secret number value") end,
  __le = function() error("attempt to compare a secret number value") end })
function issecretvalue(v) return v == SECRET end
function GetUnitSpeed() return SECRET end -- igual ao WoW Forever
function IsPlayerMoving() return state.speed > 0 end
function UnitPosition() if state.x == nil then return nil end return state.y, state.x, 0, state.inst end
function UnitOnTaxi() return state.taxi end
function UnitInVehicle() return state.vehicle end
function IsSwimming() return state.swim end
function IsMounted() return state.mount end
function UnitName() return state.name or "Ianix Mau" end
function GetRealmName() return "Teste" end
function GetCursorPosition() return 100, 300 end -- logo acima do minimapa
local NOW = os.time({ year = 2026, month = 11, day = 12, hour = 15 })
function time(t) if t then return os.time(t) end return NOW end
function date(fmt, t) return os.date(fmt, t or NOW) end

local driver
local function loadAddon()
  frames = {}
  local chunk = assert(loadfile(arg[1])); chunk()
  driver = frames[1]
  driver.scripts.OnEvent(driver, "PLAYER_LOGIN")
  driver.scripts.OnEvent(driver, "PLAYER_ENTERING_WORLD")
end
loadAddon()

local function char() return AndarilhoDB.chars[(state.name or "Ianix Mau") .. "-Teste"] end
local wasMoving = false
local function step(dt)
  local now = state.speed > 0
  if now ~= wasMoving then
    driver.scripts.OnEvent(driver, now and "PLAYER_STARTED_MOVING" or "PLAYER_STOPPED_MOVING")
    wasMoving = now
  end
  driver.scripts.OnUpdate(driver, dt)
end

local fails = 0
local function check(name, ok, detail)
  io.write(string.format("%-46s %s%s\n", name, ok and "ok" or "FAIL", detail and ("  " .. detail) or ""))
  if not ok then fails = fails + 1 end
end
local function near(name, got, want, tol)
  check(name, math.abs(got - want) <= (tol or 0.5), string.format("got=%.3f want=%.3f", got, want))
end
local function run(sec, dx)
  for _ = 1, sec * 20 do
    if dx and state.x then state.x = state.x + dx * 0.05 end
    step(0.05)
  end
end
local function clear() local c = char(); c.foot, c.mount, c.swim, c.days = 0, 0, 0, {} end
local function allText()
  local t = {}
  for _, f in ipairs(frames) do local v = rawget(f, "text"); if v then table.insert(t, v) end end
  return table.concat(t, " | ")
end

-- Medição
state.speed = 7; run(100, 7); near("correr em linha 100s @7yd/s", char().foot, 700, 3)
clear(); run(100, 0); near("correr contra a parede", char().foot, 0, 0.01)
clear(); state.speed = 7; run(10, 40); near("Charge/Blink rápido não conta", char().foot, 0, 0.01)
clear(); state.speed = 0; run(60, 20); near("parado em barco movendo", char().foot, 0, 0.01)
clear(); state.speed = 7; run(1, 7); state.x = state.x + 500; run(1, 7); near("teleporte 500yd no meio", char().foot, 14, 3)
clear(); state.x = nil; run(100); near("masmorra: estimativa 7yd/s", char().foot, 700, 3); state.x = 0
clear(); state.taxi = true; state.speed = 30; run(50, 30); state.taxi = false
near("grifo não conta", char().foot + char().mount + char().swim, 0, 0.01)
clear(); state.mount = true; state.speed = 14; run(50, 14); state.mount = false
near("montado: foot", char().foot, 0, 0.01); near("montado: mount", char().mount, 700, 3)
clear(); state.swim = true; state.speed = 4; run(50, 4); state.swim = false; near("nadando", char().swim, 200, 2)
clear(); state.speed = 7; step(30); near("tela de loading 30s", char().foot, 0, 0.01)

-- Histórico por dia
clear(); state.speed = 7; run(100, 7)
local today = char().days["2026-11-12"]
check("histórico: hoje registrado", today ~= nil)
near("histórico: hoje = total", today and today.foot or -1, char().foot, 0.001)
state.speed = 0; step(0.05)

-- Relatório: dias antigos, filtros e pesquisa
local y = 1093.6133 -- 1 km
char().days["2026-11-11"] = { foot = 2 * y, mount = 0, swim = 0 }
char().days["2026-11-06"] = { foot = 5 * y, mount = y, swim = 0 }
char().days["2026-10-20"] = { foot = 3 * y, mount = 0, swim = 0 }
SlashCmdList.ANDARILHO("relatorio")
check("relatório abre", AndarilhoReport:IsShown())
local text = allText()
check("7 dias: mostra 12/11 e 06/11", text:find("qui 12/11/2026", 1, true) and text:find("sex 06/11/2026", 1, true) and true)
check("7 dias: esconde 20/10", not text:find("20/10/2026", 1, true))
check("melhor dia 06/11", text:find("Melhor dia: |cffffffffsex 06/11/2026 · 5,00 km", 1, true) and true)
AndarilhoReportSearch:SetText("11/11"); AndarilhoReportSearch.scripts.OnTextChanged(AndarilhoReportSearch)
text = allText()
check("pesquisa 11/11", text:find("Dias listados: |cffffffff1|r", 1, true) and text:find("2,00 km", 1, true) and true)
AndarilhoReportSearch:SetText("ter"); AndarilhoReportSearch.scripts.OnTextChanged(AndarilhoReportSearch)
check("pesquisa por dia da semana (ter)", allText():find("Dias listados: |cffffffff0|r", 1, true) and true)
AndarilhoReportSearch:SetText(""); AndarilhoReportSearch.scripts.OnTextChanged(AndarilhoReportSearch)

-- "Tudo" e "Todos os personagens"
local function clickPeriod(label)
  for _, f in ipairs(frames) do
    local sc = rawget(f, "scripts")
    if rawget(f, "text") == label and sc and sc.OnClick then sc.OnClick(f); return true end
  end
end
check("botão Tudo existe", clickPeriod("Tudo"))
check("Tudo: mostra 20/10", allText():find("ter 20/10/2026", 1, true) and true)
AndarilhoDB.chars["Outro-Teste"] = { foot = 0, mount = 0, swim = 0,
  days = { ["2026-11-12"] = { foot = 10 * y, mount = 0, swim = 0 } } }
check("botão Este personagem existe", clickPeriod("Este personagem"))
check("todos: soma o outro personagem", allText():find("Todos os personagens", 1, true)
  and allText():find("Melhor dia: |cffffffffqui 12/11/2026", 1, true) and true)

-- Idioma
check("idioma automático em cliente ptBR", allText():find("A pé (caminhada)", 1, true) and true)
SlashCmdList.ANDARILHO("idioma en")
text = allText()
check("idioma en troca os textos", text:find("On foot (walking)", 1, true) and text:find("Andarilho · Report", 1, true) and true)
check("idioma en: data em ISO", text:find("Thu 2026-11-12", 1, true) and true)
check("idioma salvo", AndarilhoDB.ui.lang == "en")
SlashCmdList.ANDARILHO("language auto")
check("volta ao automático", allText():find("A pé (caminhada)", 1, true) and AndarilhoDB.ui.lang == "auto" and true)
check("botão de idioma no relatório", clickPeriod("Idioma: Automático") and AndarilhoDB.ui.lang == "pt")
state.locale = "enUS"; AndarilhoDB.ui.lang = "auto"; loadAddon()
check("cliente inglês + automático = inglês", allText():find("On foot (walking)", 1, true) and true)
SlashCmdList.ANDARILHO("idioma pt")
check("cliente inglês + pt = português", allText():find("A pé (caminhada)", 1, true) and true)
state.locale = nil; AndarilhoDB.ui.lang = "auto"

-- Minimizar e minimapa
loadAddon()
printed = {}
AndarilhoMinimizeButton.scripts.OnClick(AndarilhoMinimizeButton)
check("minimizar esconde a janela", not AndarilhoFrame:IsShown() and AndarilhoDB.ui.shown == false)
check("aviso do minimapa aparece 1 vez", #printed == 1 and printed[1]:find("minimapa", 1, true) and true)
AndarilhoMinimapButton.scripts.OnClick(AndarilhoMinimapButton, "LeftButton")
check("clique no minimapa abre", AndarilhoFrame:IsShown())
AndarilhoMinimizeButton.scripts.OnClick(AndarilhoMinimizeButton)
check("aviso não repete", #printed == 1)
AndarilhoMinimapButton.scripts.OnClick(AndarilhoMinimapButton, "LeftButton")
AndarilhoMinimapButton.scripts.OnClick(AndarilhoMinimapButton, "RightButton")
check("botão direito abre relatório", AndarilhoReport:IsShown())
AndarilhoMinimapButton.scripts.OnDragStart(AndarilhoMinimapButton)
AndarilhoMinimapButton.scripts.OnUpdate(AndarilhoMinimapButton, 0.1)
near("arrastar ícone muda o ângulo", AndarilhoDB.ui.minimapAngle, 90, 0.01)
AndarilhoMinimapButton.scripts.OnEnter(AndarilhoMinimapButton)
SlashCmdList.ANDARILHO("minimapa")
check("esconde o ícone do minimapa", not AndarilhoMinimapButton:IsShown() and AndarilhoDB.ui.minimapHidden)
loadAddon()
check("ícone continua escondido após reload", not AndarilhoMinimapButton:IsShown())
SlashCmdList.ANDARILHO("minimapa")

-- Conversão, comandos e persistência
char().foot = 1093.6133; step(1.1)
check("conversão 1 km", allText():find("1,00 km", 1, true) and allText():find("1.094 yd · 1.000 m", 1, true) and true)
SlashCmdList.ANDARILHO("total"); SlashCmdList.ANDARILHO("reset")
check("reset sem confirmar não zera", char().foot ~= 0)
SlashCmdList.ANDARILHO("reset confirmar")
check("reset zera total e histórico", char().foot == 0 and next(char().days) == nil)
SlashCmdList.ANDARILHO("trancar"); SlashCmdList.ANDARILHO("centro"); SlashCmdList.ANDARILHO("xyz")
SlashCmdList.ANDARILHO("idioma"); AndarilhoFrame.scripts.OnEnter(AndarilhoFrame)
char().foot = 42; loadAddon()
check("persistência", char().foot == 42)

-- Save antigo (1.0.x) sem histórico
AndarilhoDB = { chars = { ["Ianix Mau-Teste"] = { foot = 5, mount = 0, swim = 0 } }, ui = {} }
loadAddon()
check("save da 1.0.x continua funcionando", char().foot == 5 and type(char().days) == "table")

io.write("falhas: ", fails, "\n")
os.exit(fails == 0 and 0 or 1)
