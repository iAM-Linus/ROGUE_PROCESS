-- conf.lua
function love.conf(t)
    t.window.title = "//ROGUE_PROCESS"
    t.window.width = 640
    t.window.height = 360
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 360

    t.console = true -- Enable the LÖVE console for debugging (love.print)

    t.modules.joystick = false
    t.modules.physics = false
end