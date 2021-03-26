local function foo(cnt, ms_off, ms_on) 
--- require("wash1")(15, 3000, 5000) итого 15*8=120 сек. весь цикл
--- количество cnt нечетное! чтобы заканчивать в выкл сост обоих пинов
  
  local pin23=require("Pin::Swap")(23, {swap=0})--- реле направления
  local pin27=require("Pin::Swap")(27, {swap=cnt or 11, ms={ms_of or 3000, ms_on or 5000}}) --- симистор защиты щелчков реле 3сек выкл-5сек крутит
--~   local function simistor_off ()
--~     pin27:start(1)
--~   end
--~   local function simistor_on ()
--~     pin27:start(0)
--~   end
  local function rele_swap()
    if pin27.level == 1 then --- когда выкл
      pin23:swapPin(1) --- перекл направление реле (1 - это форсирование свопа)
    end
  end
  
  local function done()
    print("Done")
  end
  ---- поехали c выключенных обоих пинах
  pin23:start(1)
  pin27:start(1, {cb={afterSet=rele_swap, onDone=done}})
end

return foo

