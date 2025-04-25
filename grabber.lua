
GrabberClass = {}

function GrabberClass:new()
  local obj = {
    isDragging = false,
    dragStartPos = {x = 0, y = 0},
    currentMousePos = {x = 0, y = 0},
    dragOffset = {x = 0, y = 0}    }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function GrabberClass:startDrag(x, y, offsetX, offsetY)
  self.isDragging = true
  self.dragStartPos = {x = x, y = y}
  self.currentMousePos = {x = x, y = y}
  self.dragOffset = {x = offsetX or 0, y = offsetY or 0} 
end

function GrabberClass:update()
  self.currentMousePos = {x = love.mouse.getX(), y = love.mouse.getY()}
end

function GrabberClass:endDrag()
  self.isDragging = false
end

return GrabberClass