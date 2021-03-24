function foo()
  
  local pin23=require("Pin::Swap")(23, {swap=11, ms={3000, 3000}})--- реле направления
  local pin27=require("Pin::Swap")(27, {swap=0}) --- симистор защиты щелчков реле
  local function simistor_off ()
    pin27:start(1)
  end
  local function simistor_on ()
    pin27:start(0)
  end
  ---- поехали
  pin23:start(1, {cb={beforeSet=simistor_off, afterSet=simistor_on}})
end

