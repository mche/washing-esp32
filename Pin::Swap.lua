--[[
ps=require("Pin::Swap")
r = ps:new(23) или 
r = ps(23) --- с каким пином работать
--- r=require("Pin::Swap")(23, {swap=10}) сразу передать таблицу опций
r:start(0, 1000, 100)
--- или
r:start({level=0, ms={1000, 100}}) передача опций в виде таблицы
print(r.tmr:state())
r:stop()
--- или
r.tmr:stop()
r:start() продолжить с прежними настройками, но если цикл уже завершен, то не будет ничего
--- или
r.tmr:start()
r:start(1, 100, 200, 10) сразу  новый режим
---или таблица опций
r:start({level=1, ms={100, 200}, swap=10}) сразу  новый режим
r:start(0, 100, 200, 10) еще новый режим
r:start(0, 100, 200, 10, {onDone=function() print("done!") end})
--- или таблица опций
r:start({level=1, ms={100, 200}, swap=10, cb={onDone=function() print("done!") end}})
print(r.time.stop[1]-r.time.start[1]) --- завершено в микросекунд
r:start({level=1, ms={100, 200}, swap=5, cb={beforeSet=function() print("beforeSet: "..r.level) end}})
r:start({level=1, ms={100, 200}, swap=5, cb={beforeSet=function() print("beforeSet: "..r.level) end, afterSet=function() print("afterSet:" .. r.level) end}})
--]]
local _Class = {
  _VERSION = 'Pin::Swap 1.0.1'
}
_Class.__index = _Class

setmetatable(_Class, {
  __call = function (cls, ...)
      return cls:new(...)
  end
})

function _Class:new(pin, options)
  local obj = {} -- инстанс
  obj.pin = pin or 23
--[[
stop: массив node.uptime()
start: массив node.uptime()
--]]
  obj.time = {}
--[[
массив миллесекунд: первый эл -установка; 2 - сброс
--]]
  obj.ms = {} --- 
  obj.swap = nil --- кол-во переключений уровня, по умолчанию - бесконечно или по :stop()
  --[[
  разные функции:
    onDone - по завершению,
    beforeSet - перед установкой пина в любое положение
    afterSet - после установки пина 
  --]]
  obj.cb = {}

  
  setmetatable(obj, self)
  self.__index = self
  if type(options) == 'table' then
    obj:setOptions(options)
  else 
    obj:setOptions({})
  end
  return obj
end

function _Class:setOptions(options)
  self.level = (options.level ~= nil and {options.level} or { self.level ~= nil and self.level or 0})[1]
  if self.ms == nil then
    self.ms = (type(options.ms) == 'table' and { options.ms } or { {} })[1]
  elseif type(options.ms) == 'table' then
    self.ms[1] =  (options.ms[1] ~= nil and {options.ms[1]} or { self.ms[1] })[1]
    self.ms[2] =   (options.ms[2] ~= nil and {options.ms[2]} or { self.ms[2] })[1]
  end
  if self.ms[1] == nil then  self.ms[1] = 1000 end
  if self.ms[2] == nil then  self.ms[2] = 1000 end
  
  self.swap = (options.swap ~= nil and {options.swap} or { self.swap })[1]
  self.cb = (type(options.cb) == 'table' and {options.cb} or { self.cb ~= nil and { self.cb } or { {} }})[1]
  
  return self
end

function _Class:gpioConfig()
--~   gpio.write(self.pin, self.level)
  self:setPin() --- иначе конфиг включит сразу
  if self._gpioConfig == nil or self._gpioConfig.pin ~= self.pin then
    self._gpioConfig = { gpio={self.pin}, dir=gpio.OUT };
    gpio.config( self._gpioConfig )
  end
    
end

function _Class:start(level, ms_on, ms_off, swap, cb)
  if self.tmr ~= nil and level == nil then
    local started, mode = self.tmr:state()
    if not started then
      self.tmr:start()
    else
      print("Started already")
    end
    return self
  end
  
  if type(level) == 'table' then --- переданы пары ключ-значение
    self:setOptions(level)
  elseif type(ms_on) == 'table' then
    ms_on.level = level
    self:setOptions(ms_on)
  else
     self:setOptions({
      level = level, --- стартовый уровень
      ms = {ms_on, ms_off},
      swap = swap,
      cb = cb,
     })
--~     self.level = (level ~= nil and {level} or { self.level ~= nil and self.level or 0})[1] --- стартовый уровень
--~     self.ms[1] = (ms_on ~= nil and {ms_on} or { self.ms[1] ~= nil and self.ms[1] or 1000})[1]--- милисек вкл (стартового уровня!)
--~     self.ms[2] = (ms_off ~= nil and {ms_off} or { self.ms[2] ~= nil and self.ms[2] or 1000})[1] --- миллисек выкл (стартового уровня!)
--~     self.swap = (swap ~= nil and {swap} or { self.swap })[1] --- количество циклов вкл/выкл
--~     self.cb = (cb ~= nil and {cb} or { self.cb })[1] 
  end
  
  self:gpioConfig()
  
  self:_tmr() --- create + autostart timer

end

function _Class:stop(level)
  self:_tmr_single_out()
  
  if self.tmr ~= nil and self.time.stop == nil then
    self.tmr:stop()
    self.time.stop = { node.uptime() }
--~     self.tmr:unregister()
  else
    print("None started")
    return
  end
  
  if level ~= nil then
    self.level = level
--~     gpio.write(self.pin, level)
    self:setPin()
  end
end

function _Class:setPin(level)
  if self.cb.beforeSet  ~= nil then
    self.cb.beforeSet(self)
  end
  
  if level ~= nil then
    self.level = level
  end
  
  gpio.write(self.pin, self.level)
  if self.cnt ~= nil then self.cnt = self.cnt + 1 end
  
  if self.cb.afterSet  ~= nil then
    self.cb.afterSet(self)
  end
end

function _Class:swapPin(force)

  if not force and self.swap ~= nil and  self.cnt >= self.swap then
    self.time.stop = { node.uptime() }
    self.tmr:stop()
    self:_tmr_single_out()
--~     print("done: cnt="..self.cnt.."; swap="..self.swap)
    if self.cb.onDone ~= nil then
      self.cb.onDone()
    end
    return --- ничего - останов 
  end

  if self.level == 0 then  self.level = 1
  else  self.level = 0     end
--~   gpio.write(self.pin, self.level)
  self:setPin()
  return self -- продолжить
end

function _Class:_tmr() --- создать таймер
  self.cnt = 1 --- один раз уже переключилось
  if self.tmr ~= nil then
    self.time.stop = { node.uptime() }
    self.tmr:stop()
    self.tmr:unregister()
    self.tmr = nil
  end
  
  local func_single = function() 
    self:swapPin()
  end  ---  local func_single
  
  self.time.start = { node.uptime() }
  self.tmr = tmr.create()
--~   print("Timer ", self.ms[1], self.ms[2])
  self.tmr:alarm(self.ms[1]+self.ms[2], tmr.ALARM_AUTO, function()
    if self:swapPin() then
      self:_single(self.ms[1], func_single)
    end
    
  end) ---  tmr alarm auto
  
  self:_single(self.ms[1], func_single)--- обязательно сначала один второй цикл, потому что пин уже обработан при start() !!
  
end --- end _tmr()

function _Class:_single(ms, func)
  self:_tmr_single_out()
  self._tmr_single = tmr.create()
  self._tmr_single:alarm(ms, tmr.ALARM_SINGLE, func)
  return self
end --- end _single()

function _Class:_tmr_single_out()
  if self._tmr_single ~= nil then
    self._tmr_single:stop()
    self._tmr_single:unregister()
    self._tmr_single = nil
--~     print("warn: many singles tmr!")
  end
end --- _Class:_tmr_single_out()


return _Class