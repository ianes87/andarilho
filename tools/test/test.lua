-- API do WoW simulada
local frames, state = {}, nil
local function reset() state={speed=0,x=0,y=0,inst=0,taxi=false,swim=false,mount=false,vehicle=false} end
reset()
local function newObj()
  local o={}
  return setmetatable(o,{__index=function(t,k)
    if k=="SetText" then return function(s,v) s.text=v end end
    if k=="SetScript" then return function(s,n,f) local sc=rawget(s,"scripts") or {}; rawset(s,"scripts",sc); sc[n]=f end end
    if k=="CreateFontString" then return function() local f=newObj(); table.insert(frames,f); return f end end
    if k=="IsShown" then return function(s) return rawget(s,"shown")~=false end end
    if k=="SetShown" then return function(s,v) s.shown=v end end
    if k=="GetPoint" then return function() return "TOP",nil,"TOP",1,2 end end
    return function() end
  end})
end
function GetLocale() return "ptBR" end
function CreateFrame() local f=newObj(); table.insert(frames,f); return f end
UIParent=newObj(); GameTooltip=newObj(); BackdropTemplateMixin={}
SlashCmdList={}
local printed={}
function print(s) table.insert(printed,s) end
function GetUnitSpeed() return state.speed end
function UnitPosition() if state.x==nil then return nil end return state.y,state.x,0,state.inst end
function UnitOnTaxi() return state.taxi end
function UnitInVehicle() return state.vehicle end
function IsSwimming() return state.swim end
function IsMounted() return state.mount end
function UnitName() return "Ianix Mau" end
function GetRealmName() return "Teste" end

local function load_addon()
  frames={}
  local f=assert(loadfile(arg[1])); f()
  local driver=frames[1]
  driver.scripts.OnEvent(driver,"PLAYER_LOGIN")
  driver.scripts.OnEvent(driver,"PLAYER_ENTERING_WORLD")
  return driver
end
local driver=load_addon()
local function char() return AndarilhoDB.chars["Ianix Mau-Teste"] end
local function step(dt) driver.scripts.OnUpdate(driver,dt) end
local fails=0
local function near(name,got,want,tol)
  local ok=math.abs(got-want)<=(tol or 0.5)
  print2=io.write(string.format("%-34s %-4s got=%.3f want=%.3f\n",name,ok and "ok" or "FAIL",got,want))
  if not ok then fails=fails+1 end
end
local function run(sec,dx,fn) -- move dx yd/s
  for i=1,sec*20 do if dx then state.x=state.x+dx*0.05 end; if fn then fn(i) end; step(0.05) end
end
local function clear() local c=char(); c.foot,c.mount,c.swim=0,0,0 end

state.speed=7; run(100,7); near("correr em linha 100s @7yd/s",char().foot,700,3)
clear(); run(100,0); near("correr contra a parede",char().foot,0,0.01)
clear(); state.speed=0; run(60,20); near("parado em barco movendo",char().foot,0,0.01)
clear(); state.speed=7; run(1,7); state.x=state.x+500; run(1,7); near("teleporte 500yd no meio",char().foot,14,3)
clear(); state.inst=1; run(1,7); state.inst=0; near("troca de instancia",char().foot,7,3)
clear(); state.x=nil; state.speed=7; run(100); near("masmorra: sem posicao",char().foot,700,3); state.x=0
clear(); state.taxi=true; state.speed=30; run(50,30); state.taxi=false; near("grifo nao conta",char().foot+char().mount+char().swim,0,0.01)
clear(); state.mount=true; state.speed=14; run(50,14); state.mount=false; near("montado: foot",char().foot,0,0.01); near("montado: mount",char().mount,700,3)
clear(); state.swim=true; state.speed=4; run(50,4); state.swim=false; near("nadando",char().swim,200,2)
clear(); state.speed=7; step(30); near("tela de loading 30s",char().foot,0,0.01)
clear(); state.speed=7; local a=state.x; for i=1,50 do state.x=state.x+7*0.2; step(0.2) end; near("tick exato 0.2 (1o tick pos-loading nao conta)",char().foot,68.6,0.01)

-- Conversões e texto
char().foot=1093.6133; char().mount,char().swim=0,0
driver.scripts.OnUpdate(driver,0.6)
local texts={} for _,f in ipairs(frames) do local v=rawget(f,"text"); if v then table.insert(texts,v) end end
io.write(table.concat(texts," | "),"\n")
local joined=table.concat(texts,"|")
if not joined:find("1,00 km",1,true) or not joined:find("1.094 yd · 1.000 m",1,true) then fails=fails+1; io.write("FAIL conversao\n") end

char().foot=1234567.89; state.speed=0; step(0.6)
texts={} for _,f in ipairs(frames) do local v=rawget(f,"text"); if v then table.insert(texts,v) end end
io.write(table.concat(texts," | "),"\n")

-- Comandos
SlashCmdList.ANDARILHO("total"); SlashCmdList.ANDARILHO("reset")
if char().foot==0 then fails=fails+1; io.write("FAIL reset sem confirmar zerou\n") end
SlashCmdList.ANDARILHO("reset confirmar")
if char().foot~=0 then fails=fails+1; io.write("FAIL reset\n") end
SlashCmdList.ANDARILHO(""); SlashCmdList.ANDARILHO(""); SlashCmdList.ANDARILHO("trancar"); SlashCmdList.ANDARILHO("centro"); SlashCmdList.ANDARILHO("xyz")
-- Persistência
char().foot=42; local d2=load_addon(); if char().foot~=42 then fails=fails+1; io.write("FAIL persistencia\n") end
frames[2].scripts.OnEnter(frames[2])
for _,p in ipairs(printed) do io.write(p,"\n") end
io.write("falhas: ",fails,"\n"); os.exit(fails==0 and 0 or 1)
