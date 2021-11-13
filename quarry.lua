local slot = 1
while true do
    turtle.select(slot)
    slot = slot % 16 + 1
    turtle.getSelectedSlot()
end

function func()
    
end