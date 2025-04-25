require "vector"


CARD_STATE = {
  IDLE = 0,
  MOUSE_OVER = 1,
  GRABBED = 2
}

CardClass = {}


CardClass.cardBack = nil
CardClass.cardImages = {}

function CardClass.loadImages()
  CardClass.cardImages = CardClass.cardImages or {}
  CardClass.cardBack = love.graphics.newImage("assets/card/cardBack_blue3.png")

  local suits = { "hearts", "diamonds", "clubs", "spades" }

  for _, suit in ipairs(suits) do
    CardClass.cardImages[suit] = {}
    for value = 1, 13 do
      local img = love.graphics.newImage("assets/card/card_" .. suit .. "_" .. value .. ".png")
      CardClass.cardImages[suit][value] = img
    end
  end
end

function CardClass:new(x, y, suit, value)
  local obj = {
    position = Vector(x, y),
    originalPosition = Vector(x, y),
    size = Vector(60, 80),
    suit = suit or "hearts",
    value = value or 1,
    faceUp = false,
    state = CARD_STATE.IDLE,
    isMouseOver = false,
    dragOffset = Vector(0, 0),
    originalX = x,
    originalY = y
  }

  if CardClass.cardBack == nil then
    CardClass.loadImages()
  end

  setmetatable(obj, self)
  self.__index = self
  return obj
end

function CardClass:__index(key)
  if key == "x" then return self.position.x end
  if key == "y" then return self.position.y end
  return getmetatable(self)[key]
end

function CardClass:__newindex(key, value)
  if key == "x" then self.position.x = value
  elseif key == "y" then self.position.y = value
  else rawset(self, key, value) end
end

function CardClass:draw()
  local CARD_WIDTH = 80
  local CARD_HEIGHT = 120

  if self.faceUp then
    local suitImages = CardClass.cardImages[self.suit]
    local img = suitImages and suitImages[self.value]
    if img then
      local scaleX = CARD_WIDTH / img:getWidth()
      local scaleY = CARD_HEIGHT / img:getHeight()
      love.graphics.draw(img, self.position.x, self.position.y, 0, scaleX, scaleY)
    end
  else
    if CardClass.cardBack then
      local scaleX = CARD_WIDTH / CardClass.cardBack:getWidth()
      local scaleY = CARD_HEIGHT / CardClass.cardBack:getHeight()
      love.graphics.draw(CardClass.cardBack, self.position.x, self.position.y, 0, scaleX, scaleY)
    end
  end

  if self.state == CARD_STATE.MOUSE_OVER then
    love.graphics.setColor(1, 1, 0, 0.3)
    love.graphics.rectangle("fill", self.position.x, self.position.y, CARD_WIDTH, CARD_HEIGHT)
  elseif self.state == CARD_STATE.GRABBED then
    love.graphics.setColor(1, 0, 0, 0.3)
    love.graphics.rectangle("fill", self.position.x, self.position.y, CARD_WIDTH, CARD_HEIGHT)
  end

  love.graphics.setColor(1, 1, 1)
end

function CardClass:isPointInside(x, y)
  return x >= self.position.x and 
         x <= self.position.x + self.size.x and
         y >= self.position.y and 
         y <= self.position.y + self.size.y
end

function CardClass:startDrag(mouseX, mouseY)
  self.state = CARD_STATE.GRABBED
  self.dragOffset = Vector(mouseX - self.position.x, mouseY - self.position.y)
end

function CardClass:updateDrag(mouseX, mouseY)
  if self.state == CARD_STATE.GRABBED then
    self.position.x = mouseX - self.dragOffset.x
    self.position.y = mouseY - self.dragOffset.y
  end
end

function CardClass:endDrag()
  self.state = CARD_STATE.IDLE
end

function CardClass:flip()
  self.faceUp = not self.faceUp
end

return CardClass
