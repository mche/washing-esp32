-- Scan and print all found APs, including hidden ones
wifi.sta.scan({}, function(err,arr)
  if err then
    print("Scan failed:", err)
  else
    print(string.format("%-26s","SSID"),"Channel BSSID              RSSI Auth Bandwidth")
    for i,ap in ipairs(arr) do
      print(string.format("%-32s",ap.ssid),ap.channel,ap.bssid,ap.rssi,ap.auth,ap.bandwidth)
    end
    print("-- Total APs: ", #arr)
  end
end
)