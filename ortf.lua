--              O R T F
--  
-- sort of Radio music clone
-- each station is an audio file
--  
-- Change samples rep in params
-- (default is tape)
-- 
-- E1 radio station
-- E2 scrobe
-- E3 rate (-4 to 4)
--  
-- K2 loop: start / end / reset
-- k3 jump to start
-- 
-- ALT is K1
-- K1 + E2 adjust loop start
-- K1 + E3 adjust loop end
-- K1 + K3 saved  loop in tape
--  

--file = _path.dust.."code/softcut-studies/lib/whirl1.aif"
--file = _path.dust.."audio/tape/0023.wav"
local fileselect = require "fileselect"

file=nil

rate = 1.0
duration = 40.0

durationLoop=10.0
radioDirTab = nil
currentFileNdx=1

files = {}
positions = {}
durations = {}
rates = {}
loopStarts = {}
loopEnds = {}
isloaded = {}

statesKey2 = {}

radioDirTab ={}
rootDirectory=_path.dust.."audio/tape/"


alt= false

firstSample=""

phi=0

m = midi.connect(1)
tab.print(m)
m.event = function(data)
  local d = midi.to_msg(data)
  if d.type == "note_on" then
    loopStarts[currentFileNdx] = 1
    softcut.position(1,loopStarts[currentFileNdx])

  end
  
  if d.type == "cc" then
    if d.cc==9 then  
      currentFileNdx= util.round(#radioDirTab*d.val/127)+1
      fileToRefresh = 1
    elseif d.cc==14 then  
      loopStarts[currentFileNdx] = durations[currentFileNdx]*d.val/127
      softcut.loop_start(1,loopStarts[currentFileNdx])
    elseif d.cc==15 then  
      loopEnds[currentFileNdx] = durations[currentFileNdx]*d.val/127
      softcut.loop_end(1,loopEnds[currentFileNdx])    
    elseif d.cc==20 then  
      if d.val<=64 then
        rates[currentFileNdx]=(64-d.val)/64*-4
      else
        rates[currentFileNdx]=(d.val-64)/64*4
      end
      softcut.rate(1,rates[currentFileNdx])
    elseif d.cc==21 then      
      positions[currentFileNdx] = durations[currentFileNdx]*d.val/127
      softcut.position(1,positions[currentFileNdx])
    end  
  end
end


function init()

  params:add_file("firstSample", "first sample")
  params:set_action("firstSample", function(file) loadFirstSample(file) end)

  radioDirTab = util.scandir(rootDirectory)

  refreshDirectory()

  if #radioDirTab > 1 then
   file = rootDirectory..radioDirTab[1]
   load_file(file)
  end 

  oldTime = util.time()
  fileToRefresh=0

  counter = metro.init()
  counter.time = 0.15
  counter.count = -1
  counter.event = refreshFile
  counter:start()
  
  tempoSave=5.0
  counterPopup= metro.init()
  counterPopup.time = tempoSave
  counterPopup.count = -1
  counterPopup.event = showPopup
  counterPopup:start()
  
  
  showPopupFlg=0
  msgPopup=""

  -- clear buffer
  softcut.buffer_clear()
  
  softcut.event_phase(update_positions)

  softcut.buffer_read_stereo(file,0,1,-1)

 -- softcut.phase_quant(1,0.0625)
  softcut.phase_quant(1,0.000625)
  softcut.poll_start_phase()


  
  -- enable voice 1
  softcut.enable(1,1)
  -- set voice 1 to buffer 1
  softcut.buffer(1,1)
  -- set voice 1 level to 1.0
  softcut.level(1,1.0)
  -- voice 1 enable loop
  softcut.loop(1,1)
  softcut.loop_start(1,1)
  softcut.loop_end(1,loopEnds[currentFileNdx])
  -- set voice 1 position to 1
  softcut.position(1,1)
  -- set voice 1 rate to 1.0
  softcut.rate(1,1.0)
  -- enable voice 1 play
  --softcut.rate_slew_time(1,0.1)
 -- softcut.level_slew_time(1,2)
  softcut.fade_time(1,0.01)
  softcut.play(1,1)
end


function showPopup()
  if showPopupFlg==1 then
    showPopupFlg=0
  end
end


function refreshDirectory()
  radioDirTab = util.scandir(rootDirectory)
  tab.print(radioDirTab)

  for key,value in pairs(radioDirTab) do
    local iToDelete=1
    local extension = GetFileExtension(value)
    if extension ~= "wav" and extension ~= "WAV" then
          print("extension2="..extension)

      table.remove (radioDirTab ,key)
    end
    files[key]= value
    positions[key]=1.0
    durations[key]=0  
    rates[key]=0.0  
    loopStarts[key]=1.0  
    loopEnds[key]=0  
    isloaded[key]=0    
    statesKey2[key]='no_loop' 
  end
end

function GetFileWithoutExtension(url)
  return url:sub(1,url:len()-4)

end

function GetFileExtension(url)
 -- return url:match("^.+(%..+)$")
  return url:match "[^.]+$" -- To match file extension
end

function GetFileNameAndExtension(url)
 -- return url:match("^.+(%..+)$")
  return url:match("^.+(%..+)$") -- To match file name + file extension
end

function SplitFilename(strFilename)
	-- Returns the Path, Filename, and Extension as 3 values
	return string.match(strFilename, "(.-)([^\\]-([^\\%.]+))$")
end

function loadFirstSample(file)
  firstSample=file
  rootDirectory=file:match('^(/.+/)')
  refreshDirectory()
  for key,value in pairs(files) do
    local fullPath=rootDirectory..value
    if file == fullPath then
      currentFileNdx = key
    end
end
  if isloaded[currentFileNdx]==0 then
    load_file(file)
  end
  refreshSoftcut()

end


function update_positions(i,pos)
  positions[currentFileNdx] = pos
  redraw()
end



function refreshSoftcut()
  softcut.buffer_clear()
  softcut.buffer_read_stereo(rootDirectory..files[currentFileNdx],0,1,-1)
  softcut.position(1,positions[currentFileNdx])
  softcut.rate(1,rates[currentFileNdx])
 
  softcut.loop_start(1,loopStarts[currentFileNdx])
  softcut.loop_end(1,loopEnds[currentFileNdx])
  softcut.play(1,1)
end

function refreshFile()
  if fileToRefresh==1 then
    file = rootDirectory..radioDirTab[currentFileNdx]
    load_file(file)
    refreshSoftcut()
  end
  fileToRefresh = 0
  redraw()
end

function enc(n,d)
  if n==1  then
    if (currentFileNdx+d)<= #radioDirTab and (currentFileNdx+d)>0 then
      currentFileNdx =  currentFileNdx + d
      fileToRefresh = 1
    end
  elseif n==2 and alt==false then
    local delta =d/20

    if math.abs(d)>1 then
      delta =delta + (d-1) * (loopEnds[currentFileNdx]/60)
    end
    positions[currentFileNdx] = util.clamp(positions[currentFileNdx]+delta,1,durations[currentFileNdx])
    durationLoop=loopEnds[currentFileNdx]-loopStarts[currentFileNdx]
    softcut.position(1,positions[currentFileNdx])

    if positions[currentFileNdx]<loopStarts[currentFileNdx] then
      loopStarts[currentFileNdx]= positions[currentFileNdx]
      loopEnds[currentFileNdx]= loopStarts[currentFileNdx]+durationLoop

      softcut.loop_start(1,loopStarts[currentFileNdx])
      softcut.loop_end(1,loopEnds[currentFileNdx])
      
    elseif  positions[currentFileNdx]>loopEnds[currentFileNdx] then
      loopEnds[currentFileNdx]= positions[currentFileNdx]

      loopStarts[currentFileNdx]= loopEnds[currentFileNdx]-durationLoop

      softcut.loop_start(1,loopStarts[currentFileNdx])
      softcut.loop_end(1,loopEnds[currentFileNdx])
    end
  elseif n==3 and alt==false then
    rates[currentFileNdx]= util.clamp(rates[currentFileNdx]+d/100,-4.0,4.0)
    softcut.rate(1,rates[currentFileNdx])
  elseif n==2 and alt==true then
    delta =d/100
    loopStarts[currentFileNdx] = util.clamp(loopStarts[currentFileNdx]+delta,1,durations[currentFileNdx])
    softcut.loop_start(1,loopStarts[currentFileNdx])
  elseif n==3 and alt==true then   
    delta =d/100
    loopEnds[currentFileNdx] = util.clamp(loopEnds[currentFileNdx]+delta,1,durations[currentFileNdx])
    softcut.loop_end(1,loopEnds[currentFileNdx])
  end
  redraw()
end


function key(n,z)
  
 -- print(n..z)
    if n == 1 then
      alt = z == 1 and true or false
 -- print(alt)
  
  elseif n == 2 and alt == false then
    if z == 1 then
      if statesKey2[currentFileNdx]=='no_loop'  then
        if rates[currentFileNdx]>0 then
              loopStarts[currentFileNdx] = positions[currentFileNdx]
        else
              loopEnds[currentFileNdx] = positions[currentFileNdx]
        end
        statesKey2[currentFileNdx]='loop_start'
      elseif statesKey2[currentFileNdx]=='loop_start' then
        if rates[currentFileNdx]>0 then
          loopEnds[currentFileNdx] = positions[currentFileNdx]
        else
          loopStarts[currentFileNdx] = positions[currentFileNdx]
        end
        
        statesKey2[currentFileNdx]='loop_end'
        softcut.loop_start(1,loopStarts[currentFileNdx])
        softcut.loop_end(1,loopEnds[currentFileNdx])
      elseif statesKey2[currentFileNdx]=='loop_end' then
        loopStarts[currentFileNdx] = 1
        loopEnds[currentFileNdx] = durations[currentFileNdx]
        statesKey2[currentFileNdx]='no_loop'
        softcut.loop_start(1,loopStarts[currentFileNdx])
        softcut.loop_end(1,loopEnds[currentFileNdx])
      end
    end
  elseif n == 3 and alt==false then
    if z == 1 then
      softcut.position(1,loopStarts[currentFileNdx])
    end
  
  elseif n == 2 and alt==true then  

  elseif n == 3 and alt==true then  
    alt=false
    local newFileName=GetFileWithoutExtension(radioDirTab[currentFileNdx]):match "[^/]+$" .."_"..math.floor( (loopStarts[currentFileNdx] * 10^2) + 0.5) / (10^2)
    local file_path = _path.dust.."audio/tape/" .. newFileName.. ".wav"

    msgPopup=newFileName
    popup(msgPopup)
    softcut.buffer_write_stereo(file_path, loopStarts[currentFileNdx], (loopEnds[currentFileNdx]-loopStarts[currentFileNdx]) + 1 + .12)
    table.insert(radioDirTab, currentFileNdx, newFileName..".wav")
    
    table.insert(files, currentFileNdx, newFileName..".wav")
    table.insert(positions, currentFileNdx, 1.0)
    table.insert(durations, currentFileNdx, 0)
    table.insert(rates, currentFileNdx, 0.0)
    table.insert(loopStarts, currentFileNdx, 1)
    table.insert(loopEnds, currentFileNdx, 0)
    table.insert(isloaded, currentFileNdx, 0)
    table.insert(statesKey2, currentFileNdx, 'no_loop')

    local reloadFile = metro.init(reloadFile, tempoSave, 1)
    reloadFile:start()
    end
end

function reloadFile()
  fileToRefresh = 1
end

function popup(msg)
  showPopupFlg=1
  msgPopup=msg
end

function selectFile()
print("loadf")

end


function redraw()
  screen.level(5)
  screen.clear()
  screen.line_width(1)

  xradioScreen=100
  widthradio=128-xradioScreen
  screen.rect(xradioScreen,1,128-xradioScreen,3)

  local xProgress=(positions[currentFileNdx]-1)/(durations[currentFileNdx]-1)
  screen.move(xradioScreen+ currentFileNdx/#radioDirTab*widthradio,1)
  screen.line_rel(0,2)
  screen.level(7)
  screen.move(5,20)
  screen.font_size (15)
  screen.font_face ('3')
  screen.text(GetFileWithoutExtension(radioDirTab[currentFileNdx])) 
  screen.font_size (10)
  local yProgress=23
  screen.level(7)
  screen.move(30,42)
  screen.text_center("position")
  screen.move(30,55)
  local strPos=string.format("%.1f",positions[currentFileNdx]).."/"..string.format("%.1f",durations[currentFileNdx])
  screen.text_center(strPos)
  screen.move(110,42)
  screen.text_center("rate")
  screen.move(110,55)
  screen.text_center(string.format("%.2f",rates[currentFileNdx]))
  screen.level(15)
  screen.rect(5+ (positions[currentFileNdx]-1)/(durations[currentFileNdx]-1)*120,yProgress,1,9)
  screen.rect(5+ (loopStarts[currentFileNdx]-1)/(durations[currentFileNdx]-1)*120,yProgress+3,1,3)
  screen.rect(5+ (loopEnds[currentFileNdx]-1)/(durations[currentFileNdx]-1)*120,yProgress+3,1,3)
  screen.stroke()
  drawLissajou()
  screen.stroke()
  screen.font_size (9)
  screen.level(15)
  
  screen.move(127,16)
  if showPopupFlg==1 then
    drawPopUp()
  end
  screen.update()
end

function drawPopUp()
  screen.clear()
  screen.move(64,25)
  screen.level(10)
  screen.font_size (15)
  screen.font_face ('3')
  screen.text_center(msgPopup)
  screen.move(64,45)
  screen.text_center("saved!")
end

function drawLissajou()
	a=1
	b=currentFileNdx
	A=14
	B=10
	phi=0
	t=0
		
	tglobal=0
	yLissajou=45
		
  local loopLength=loopEnds[currentFileNdx]-loopStarts[currentFileNdx]
  local loopPosition=(positions[currentFileNdx]-loopStarts[currentFileNdx]-1)/loopLength
  local globalPosition= (positions[currentFileNdx]-1)/(durations[currentFileNdx]-1)

	period = math.pi * 2
  numberOfPoints = math.ceil(period * 2)
  angleStep = period / numberOfPoints
    
  A=14*loopLength/durations[currentFileNdx]
		
	local phi = (globalPosition)*2*math.pi
	local phi2 = (loopPosition*2*math.pi)
	tglobal=	globalPosition*numberOfPoints
	tloop=	loopPosition*numberOfPoints

	tStart=(loopStarts[currentFileNdx]-1)/durations[currentFileNdx]*numberOfPoints
	tEnd=(loopEnds[currentFileNdx])/durations[currentFileNdx]*numberOfPoints

  screen.stroke()

  screen.level(5)
	xStart=70+ (A * math.sin(a*angleStep+phi))
	yStart=yLissajou + (B * math.sin(b*angleStep))
  for i=1,numberOfPoints do
    t=angleStep*i
	  x=70+ (A * math.sin(a*t+phi))
		y=yLissajou + (B * math.sin(b*t))
		screen.line (x, y)
	end
	screen.line (xStart, yStart)
  screen.stroke()
end


function load_file(file)
  if util.file_exists(file) == true then
    local ch, samples, samplerate = audio.file_info(file)
    duration = samples/samplerate
    local tmpLoaded=isloaded[currentFileNdx]
    
    if tmpLoaded ==0 then
      durations[currentFileNdx] = duration
      positions[currentFileNdx] = 1.0
      loopStarts[currentFileNdx] = 1.0
      loopEnds[currentFileNdx] = duration
      rates[currentFileNdx] = 1.0
      isloaded[currentFileNdx]=1
    end
  else print "read_wav(): file not found" end
end
