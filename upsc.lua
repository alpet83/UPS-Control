local sprintf = string.format
local function wprintf(s, ...)
 ODS ( sprintf(s,...) )
end


BATT_VOLTAGE_MIN = 12
BATT_VOLTAGE_MAX = 12


strpos = string.find

function init()
 tx_str('QP')
 tx_str('MD') 
 wprintf("[~T]. #DBG: battery voltage configuration =~C0C %.1f~C0B -~C0A %.1f~C07 V", BATT_VOLTAGE_MIN, BATT_VOLTAGE_MAX)
 if BATT_VOLTAGE_MAX <= BATT_VOLTAGE_MIN then
    for k, v in pairs(_G) do
     if type(v) == "number" then
        wprintf('~C0F %-10s~C0B =~C0D %f ~C07', k, v)
     end 
    end
    error("#FATAL: battery not configured!")  
    
 end
 
end

local last_status = 'IXM'

local qcnt = 1
local dis_time = 0
local dis_count = 0
local dis_stat = ''  -- stats file
local last_test = 0
local batt_vcurr = 0  -- EMA value

function query_status()
 qcnt = qcnt + 1
 
 if ( qcnt % 111 ~= 0) and ( last_status == "IM" ) then 
    return
 end
 
 
 if qcnt % 10 == 0 then
    tx_str('F')
 elseif qcnt % 10 == 5 then
    tx_str('I')
 else
    tx_str('Q1')     
 end
     
 
end

function strin(a, b)
 return strpos(a, b) ~= nil
end

function v2cl (cl)
 local diff = BATT_VOLTAGE_MAX - BATT_VOLTAGE_MIN;
 return ( cl - BATT_VOLTAGE_MIN ) / diff  * 100.0  -- min voltage 84, norm voltage 110
end

function split_str(s, pat)
  local vals = {}  
            
  for v in string.gmatch(s, pat) do
   if v then 
      v = tonumber(v) or 0
      table.insert (vals, v)
      -- wprintf(" ~C0D %s~C07 ", v)       
   end   
     
  end -- for
  return vals
end

function only_chars(s, chars)
 local cnt = 0
 
 for i = 1, s:len() do
   for n = 1, chars:len() do
      if s:byte(i) == chars:byte(n) then         
         cnt = cnt + 1   
      end
   end -- inner for
   
 end
 
 if cnt ~= s:len() then
    wprintf(" only_chars('%s', '%s') result = %d", s, chars, cnt)
 end    
 return cnt
end

last_minute = ''

function bit_test(value, bit)
 value = value or '000000000'
  
 if type(value) == "number" then
    value = sprintf("%08b", value)  -- not tested!  
 end 
 bit = 8 - bit
 return value:sub(bit, bit) == '1' 
end


function test_discharge(cl, status)
 dis_time = elapsed_time(1) / 1000.0
 
 if ( math.abs(dis_time - last_test) < 10 ) then 
     return
 end

 last_test = dis_time
  
 if (cl < 10) and (dis_time > 10) or bit_test(status, 6) or bit_test(status, 2) then
   wprintf("[~T]. #WARN: charge level to low, executing script...")
   shell_exec('', 'on_discharge.cmd');
 end
end


function parse_rx(rx)
 if rx:byte(1) == 40 then
    rx = rx:sub(2)
 end
 
  
 rx = rx:gsub("   ", " ")
 rx = rx:gsub("  ", " ")
 -- rx = rx:gsub(" ", ",")
 
 -- trim
 while ( rx:len() > 1 ) and ( rx:byte() == 32 ) do 
   rx = rx:sub(2)
 end   
 

 wprintf("[~T].~C0F #RX: ~C0E '%s'~C07", rx)
 
 
 
 local dts, ctr = local_time()
 
 local status = rx:sub(-8)
 
 local coll = { voltage = { 0, 0 } , load = { 0, 0 }, charge = { 0, 0 }, temp = { 0, 0 } }
 
 function collect(key, value, reset)
 
  value = tonumber(value) 
  local pair = coll[key];
  pair[1] = pair[1] + value;
  pair[2] = pair[2] + 1;
  
  if reset then
     coll[key] = { 0, 0 }
  else
     coll[key] = pair
  end
  
  return pair[1] / pair[2];
 end

 
 
 
 if ( status:len() == 8 ) and only_chars(status, "01") == 8 then
    --  (235.1 235.1 220.2   7 50.0 2.30 36.0 00000001
    local vals = split_str(rx, "([%S]*) ")    
    
    
    if table.getn(vals) < 7 then
       return 
    end
    
    local test = ""    
    for i, v in ipairs(vals) do
     test = test .. sprintf("%d = '%s'; ", i, v or 'nil' )
    end
    
    -- wprintf("test split: %s", test)          
    
    
    -- voltage per bank, must be ~2.30 V after full charge
    -- voltage of critical discharge = 1.75V 
    
    local cl = vals[6]
    
    if (batt_vcurr > 0) then
        batt_vcurr = batt_vcurr * 0.95 + cl * 0.05
    else
        batt_vcurr = cl
    end      
        
    
    --wprintf("cl_ratio = %.3f", vals[6])
    
    -- cl = ( cl - 1.75 ) * 100.0 / (2.12 - 1.75) -- linear conversion
    
    local vtp = { }
    -- this data retrieved with soft discharge ~11% load 
    table.insert (vtp, { 100, 2.30, 0 })
    table.insert (vtp, {  97, 2.15,   13.34 })
    table.insert (vtp, {  90, 2.13,  500.0 })
    table.insert (vtp, {  80, 2.12, 1000.0 })
    table.insert (vtp, {  70, 2.11, 1000.0 })
    table.insert (vtp, {  60, 2.1,  1000.0 })
    table.insert (vtp, {  50, 2.09, 1000.0 }) 
    table.insert (vtp, {  40, 2.04,  100.0 })
    table.insert (vtp, {  30, 2.03, 1000.0 })
    table.insert (vtp, {  20, 2.00,  333.3 })
    table.insert (vtp, {  10, 1.89,   90.9 })
    table.insert (vtp, {   0, 1.75,   71.4 })
    table.insert (vtp, {   0,    0,    0.0   }) 
    
    cl = 100.0
    -- aproximation search
    for i = 1, #vtp do
     local r = vtp[i]
     local v = r[2]
     if batt_vcurr >= v then
        -- [[ 2.079 - 2.07 = 0.001  
        local delta = batt_vcurr - v
        cl = delta * r[3]; 
        wprintf(' voltage =~C0D %.3fV~C07, level =~C0F %d~C07, delta =~C0D %.3fV~C07 (~C0E %.1f%%~C07) ', batt_vcurr, r[1], delta, cl)
        cl = cl + r[1]
        break         
     end     
    end
    
    
    
    cl = math.min(cl, 100)
    
    test_discharge(cl)
    
    local mm = format_time('nn', ctr)
    
    if (mm ~= last_minute) then
       last_minute = mm
       handle_value("Voltage_In",   ctr,        collect('voltage', vals[1], true))
       handle_value("Load_Level",  ctr,         collect('load', vals[4], true ))
       handle_value("Charge_Level",  ctr,       collect('charge', cl, true ))
       handle_value("Temperature",  ctr,        collect('temp', vals[7], true) )
    else
       collect('voltage', vals[1])       
       collect('load',    vals[4])
       collect('charge',  cl)
       collect('temp',    vals[7])
    end        
    
    status = rx:sub(-8)
    local st = status  -- binary status
    local warn = 1
    local lb = status:sub(-1)
    
    
    
    if bit_test(st, 2) then status = "self_test" end
    if bit_test(st, 7) then 
       status = "AC loss"
       warn = 7
    end
    
    if st:sub(1, 7) == "0000000" then 
       status = "normal"
       dis_time = 0
       last_test = 0
       start_timer(1) -- always restart
    else        
       test_discharge(cl, st)      
    end
    
    if bit_test(st, 6) then 
       status = "Battery low"
       warn = 9
       test_discharge(1, st)
    end    
        
    if (status ~= 'normal') or (cl < 100) then
       dis_stat = '$(ExePath)..\\logs\\UPS_charge.'..FormatDate('yymmdd') .. '.stat'
       local s = sprintf("%.1f;%.2f;%.3f;%.1f\n", dis_time, vals[6], batt_vcurr, cl)        
       fputs(dis_stat, s)  
    end    
        
    
    if status ~= last_status then
       last_status = status
       status_changed(status, warn)
    end
               
    -- wprintf(" v = %.1f, ll = %.0f, t = %.1f ", vals[1], vals[4], vals[7] ) 
 end 
 
 if rx:len() < 60 then 
    return
 end
 
 
 if strin (rx, " I") or strin (rx, " L") or strin (rx, " A") or strin (rx, " E") then
 
    local status = string.sub(rx, -3)
    status = status:gsub(" ", "")
    local ch = status:sub(2, 2)
    local nst = status
    
    if ( ch == "I" ) or ( ch == "L" ) then
       nst = status:gsub(ch, "*")
    end
    
    if status:len() >= 3 then                
                                  
    end  
    wprintf(" ch = %s, status = %s, new_status = %s ", ch, status, nst)
    
    status = nst
    
    
    if status ~= last_status then
       local warn = 1       
       if ( status == "E*" )   then warn = 3 end
       if ( status == "E*K" )  then warn = 5 end
       if ( status == "A*" )   then warn = 7 end
       if ( status == "A*K" )  then warn = 9 end
       last_status = status
       status_changed(status, warn)
    end                

    
    
    -- */10  * *  *    *  root  /usr/sbin/testinet
    
    local vals = split_str(rx, "%d%S*%d") 
    handle_value("Voltage_In",   ctr, vals[1])          
    local cl = tonumber (vals[11])
       
    cl = v2cl ( cl ) 
    if cl < 0 then
       -- TODO: случай тяжелого разряда батарей: необходимо выключение системы  
       cl = 0      
    end 
     
    if cl > 100 then
       cl = 100
    end 
    
      
    handle_value("Charge_Level", ctr, cl )
    test_discharge(cl)
    
    handle_value("Load_Level",  ctr, vals[7] )
    handle_value("Temperature",  ctr, vals[12] )
  
    local prefix = status:sub(1, 2)
    
    
    if ( prefix == "E*" ) or ( prefix == "A*" ) or ( prefix == "I*" ) then       
       wprintf("[~T].~C0C #WARN:~C07 discharge time =~C0F %.1f~C07 sec ", dis_time)
    end
    
    if ( status == "E*K" ) or 
       ( status == "E*" ) and ( dis_time >= 120 ) then
       tx_str("CT") -- нефиг зря разряжать батарею
       dis_count = dis_count + 1
    end
    
    if ( status == "IM" ) then
       if (dis_time > 0) then
          wprintf("[~T]. #DBG: returned to normal state.")
       end
       dis_time = 0  
    end
      
 end
 
end