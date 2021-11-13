--[[
    quarry.lua - a simple quarry script.
    The turtle running this script must satisfy the following conditions:

        * there must be a chest behind the turtle in which it will put
          the collected goods
        * there must be a chest to the right of the turtle from which it
          will draw fuel
        * at spawn, the turtle must be facing east (this is only so that
          the internal values make sense. If you want the turtle to be confined
          within one chunk, do this and put the turtle at the left-back corner
          of the chunk, while facing east of course)

    Made by boolean_coercion.
]]


local disp = {x = 0, y = 0, z = 0}

--[[
    This variable keeps track of the turtle's orientation.
    North = 1, and the value increases going Counter-Clockwise

    We assume the turtle is facing with the positive direction of the X axis
    (AKA east)
]]
local NORTH, WEST, SOUTH, EAST = 1, 2, 3, 4
local facing = EAST
local cached_facing = facing -- used by the goBack function

-- this variable keeps track of the overall Z direction travel
local going_north = true

--[[
    Determine whether the turtle has enough fuel to continue going,
    or whether it should start heading back/refuel.
]]
function canContinue()
    local distance = disp.x + disp.y + disp.z
    local fuel_remaining = turtle.getFuelLevel()

    return (fuel_remaining - 1) > (distance + 1)
end

--[[
    Try to move the turtle down, digging if there's a block in the way.
    Returns the value passed from turtle.down() along with digDown's
    reason, if any.
]]
function moveDigDown()
    local reason
    if turtle.detectDown() then
        _, reason = turtle.digDown()
    end

    local moved = turtle.down()
    if moved then
        disp.y = disp.y - 1
    end
    return moved, reason
end


local movements = {[NORTH] = {0, -1}, [WEST] = {-1, 0},
                   [SOUTH] = {0, 1}, [EAST] = {1, 0}}
--[[
    Try to move the turtle forwards, digging if there's a block in the way.
    Returns the value passed from turtle.forward() along with dig's
    reason, if any.
]]
function moveDigForward()
    local reason
    if turtle.detect() then
        _, reason = turtle.dig()
    end

    local moved = turtle.forward()
    if moved then
        local movement_array = movements[facing]
        disp.x = disp.x + movement_array[1]
        disp.z = disp.z + movement_array[2]
    end
    return moved, reason
end

local valuable_infixes = {"_ore", "coal", "diamond", "emerald", "redstone", "lapis"}
--[[
    Searches the turtle's inventory for junk (anything that isn't an ore or other
    valuable item) and drops it.

    Return value indicates whether the turtle has any free spots after this operation
    has completed.
]]
function dropJunk()
    local hasEmpty = false

    for slot=1,16 do
        local item = turtle.getItemDetail(slot)
        if item == nil then
            hasEmpty = true
        else
            local dump = true
            for _, infix in ipairs(valuable_infixes) do
                if string.find(item.name, infix) ~= nil then
                    dump = false
                    break
                end
            end

            if dump then
                turtle.select(slot)
                turtle.drop()
                hasEmpty = true
            end
        end
    end

    return hasEmpty
end

--[[
    Drops all of the coal in the turtle's inventory.
    If invert == true, does the opposite: drop all of the *non* coal
    in the turtle's inventory.
]]
function dropCoal(invert)
    for slot=1,16 do
        local item = turtle.getItemDetail(slot)
        if item ~= nil then
            if (string.find(item.name, "coal") == nil) == invert then
                turtle.select(slot)
                turtle.drop()
            end
        end
    end
end

--[[
    This function calls turtle.turnRight and changes the facing
    variable accordingly.
]]
function turnRight()
    turtle.turnRight()

    -- effectively subtracts 1 while staying in the range [1, 4]
    facing = (facing + 2) % 4 + 1
end

--[[
    This function calls turtle.turnLeft and changes the facing
    variable accordingly.
]]
function turnLeft()
    turtle.turnLeft()

    facing = (facing % 4) + 1
end

--[[
    Takes the turtle home (displacement 0), while preserving the disp table
    for easy go-back-ery.
    Also updates the cached_facing variable to be used with goBack.
]]
function goHome()
    cached_facing = facing
    for _=disp.y,-1 do
        turtle.up()
    end

    repeat
        turnRight()
    until facing == SOUTH
    for _=disp.z,1,-1 do
        turtle.forward()
    end

    turnRight() -- now facing west
    for _=disp.x,1,-1 do
        turtle.forward()
    end

    dropCoal(true)
    turnLeft() -- now facing south again
    dropCoal(false)
end

--[[
    Goes back to the place stored in the displacement table, in order for
    operation to continue as if nothing happened.
]]
function goBack()
    repeat
        turnRight()
    until facing == EAST

    for _=disp.x,1,-1 do
        turtle.forward()
    end

    turnLeft() -- now facing north
    for _=disp.z,1,-1 do
        turtle.forward()
    end

    repeat
        turnRight()
    until facing == cached_facing

    for _=disp.y,-1 do
        turtle.down()
    end
end

function refresh()
    goHome() -- now facing south
    turtle.suck()
    turtle.refuel()

    if turtle.getFuelLevel() < 50 then
        error("Not enough fuel for normal operation! Aborting.")
    end
    goBack()
end

function turnAround()
    local turn_left = (facing == EAST and going_north) or (facing == WEST and not going_north)

    if turn_left then
        turnLeft()
    else
        turnRight()
    end

    if (going_north and disp.z == 15) or (not going_north and disp.z == 0) then
        moveDigForward()
    end

    if turn_left then
        turnLeft()
    else
        turnRight()
    end
end

function main()
    if turtle.getFuelLevel() < 50 then
        -- Get fuel from the fuel chest
        turnRight()
        turtle.suck()
        turnLeft()
        -- TODO: maybe find the fuel in case it's not in the selected spot
        turtle.refuel()

        if turtle.getFuelLevel() < 50 then
            error("Not enough fuel for normal operation! Aborting.")
        end
    end

    while true do
        if not moveDigDown() then
            goHome()
            return
        end

        if not canContinue() then
            refresh()
        end

        local z_limit = going_north and 15 or 0 -- going_north ? 15 : 0
        repeat
            local x_limit = (facing == EAST) and 15 or 0
            repeat
                if not moveDigForward() then
                    goHome()
                    return
                end

                if not canContinue() then
                    refresh()
                end
            until disp.x == x_limit

            local hasEmptySpots = dropJunk()
            if not hasEmptySpots or not canContinue() then
                refresh()
            end

            if not turnAround() then
                goHome()
                return
            end

            if not canContinue() then
                refresh()
            end
        until disp.z == z_limit
    end
end

main()