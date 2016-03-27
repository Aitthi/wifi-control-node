parsePatterns =
  nmcli_line: new RegExp /([^:]+):\s+(.+)/

connectionStateMap =
  connected: "connected" # Win32 & Linux
  disconnected: "disconnected" # Win32 & Linux
  connecting: "connecting"  # Linux

powerStateMap =
  enabled: true   # linux
  disabled: false # linux

module.exports =
  autoFindInterface: ->
    @WiFiLog "Host machine is Linux."
    # On linux, we use the results of `nmcli device status` and parse for
    # active `wlan*` interfaces.
    findInterfaceCom = "nmcli -m multiline device status | grep wlan"
    @WiFiLog "Executing: #{findInterfaceCom}"
    _interfaceLine = @execSync findInterfaceCom
    parsedLine = parsePatterns.nmcli_line.exec( _interfaceLine.trim() )
    _interface = parsedLine[2]
    if _interface
      _iface = _interface.trim()
      _msg = "Automatically located wireless interface #{_iface}."
      @WiFiLog _msg
      return {
        success: true
        msg: _msg
        interface: _iface
      }
    else
      _msg = "Error: No network interface found."
      @WiFiLog _msg, true
      return {
        success: false
        msg: _msg
        interface: null
      }

  #
  # For Linux, parse nmcli to acquire networking interface data.
  #
  getIfaceState: ->
    interfaceState = {}
    #
    # (1) Get Interface Power State
    #
    powerData = @execSync "nmcli networking"
    interfaceState.power = powerStateMap[ powerData.trim() ]
    if interfaceState.power
      #
      # (2) First, we get connection name & state
      #
      foundInterface = false
      connectionData = @execSync "nmcli -m multiline device status"
      connectionName = null
      for ln, k in connectionData.split '\n'
        try
          parsedLine = parsePatterns.nmcli_line.exec( ln.trim() )
          KEY = parsedLine[1]
          VALUE = parsedLine[2]
          VALUE = null if VALUE is "--"
        catch error
          continue  # this line was not a key: value pair!
        switch KEY
          when "DEVICE"
            foundInterface = true if VALUE is @WiFiControlSettings.iface
          when "STATE"
            interfaceState.connection = connectionStateMap[ VALUE ] if foundInterface
          when "CONNECTION"
            connectionName = VALUE if foundInterface
        break if KEY is "CONNECTION" and foundInterface # we have everything we need!
      # If we didn't find anything...
      unless foundInterface
        return {
          success: false
          msg: "Unable to retrieve state of network interface #{@WiFiControlSettings.iface}."
        }
      if connectionName
        #
        # (3) Next, we get the actual SSID
        #
        try
          ssidData = @execSync "nmcli -m multiline connection show \"#{connectionName}\" | grep 802-11-wireless.ssid"
          parsedLine = parsePatterns.nmcli_line.exec( ssidData.trim() )
          interfaceState.ssid = parsedLine[2]
        catch error
          return {
            success: false
            msg: "Error while retrieving SSID information of network interface #{@WiFiControlSettings.iface}: #{error.stderr}"
          }
      else
        interfaceState.ssid = null
    else
      interfaceState.connection = connectionStateMap[ VALUE ]
      interfaceState.ssid = null
    return interfaceState
