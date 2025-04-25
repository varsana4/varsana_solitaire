io.stdout:setvbuf("no")
require "card"
require "grabber"
require "vector"


local CARD_WIDTH = 80
local CARD_HEIGHT = 120
local VERTICAL_SPACING = 30
local HORIZONTAL_SPACING = 20
local WASTE_OFFSET = 20



local SUITS = {"hearts", "diamonds", "clubs", "spades"}
local VALUES = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13} 


local PILE_TYPE = {
  STOCK = "stock",
  WASTE = "waste",
  FOUNDATION = "foundation",
  TABLEAU = "tableau"
}


local grabber
local stockPile
local wastePile
local foundationPiles
local tableauPiles
local draggedCards
local dragOriginPile

gameOver = false


local PileClass = {}

function PileClass:new(x, y, pileType)
  local obj = {
    x = x,
    y = y,
    width = CARD_WIDTH,
    height = CARD_HEIGHT,
    pileType = pileType,
    cards = {}
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function PileClass:update()
  for i, card in ipairs(self.cards) do
    if self.pileType == PILE_TYPE.TABLEAU then
      card.x = self.x
      card.y = self.y + (i - 1) * VERTICAL_SPACING
    else
      card.x = self.x
      card.y = self.y
    end
  end
end


function PileClass:draw()
  love.graphics.setColor(1, 1, 1, 0.2)
  love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 5, 5)
  love.graphics.setColor(1, 1, 1, 1)

  if self.pileType == PILE_TYPE.TABLEAU then
    for _, card in ipairs(self.cards) do
      card:draw()
    end
  elseif self.pileType == PILE_TYPE.WASTE then
    local startIndex = math.max(1, #self.cards - 2)
    for i = startIndex, #self.cards do
      love.graphics.push()
      love.graphics.translate((i - startIndex) * WASTE_OFFSET, 0)
      self.cards[i]:draw()
      love.graphics.pop()
    end
  else
    if #self.cards > 0 then
      self.cards[#self.cards]:draw()
    end
  end
end

function PileClass:isEmpty()
  return #self.cards == 0
end

function PileClass:addCard(card)
  
  card.x = self.x
  card.y = self.y
  
  if self.pileType == PILE_TYPE.TABLEAU then

    if #self.cards > 0 then
      card.y = self.y + (#self.cards * VERTICAL_SPACING)
    end
  end
  
  table.insert(self.cards, card)
end

function PileClass:getTopCard()
  if #self.cards > 0 then
    return self.cards[#self.cards]
  end
  return nil
end

function PileClass:removeTopCard()
  if #self.cards > 0 then
    local card = table.remove(self.cards, #self.cards)
    return card
  end
  return nil
end

function PileClass:removeCards(startIndex)
  local removedCards = {}

  if startIndex <= #self.cards then
    while #self.cards >= startIndex do
      local card = table.remove(self.cards)
      table.insert(removedCards, 1, card)
    end
  end

  return removedCards
end

function PileClass:findCardAt(x, y)
  if self.pileType == PILE_TYPE.TABLEAU then
    for i = #self.cards, 1, -1 do
      local cardX = self.x
      local cardY = self.y + (i - 1) * VERTICAL_SPACING

      if x >= cardX and x <= cardX + self.width and
         y >= cardY and y <= cardY + self.height then
        return i
      end
    end
  elseif self.pileType == PILE_TYPE.WASTE and #self.cards > 0 then
    local startIndex = math.max(1, #self.cards - 2)

    for i = #self.cards, startIndex, -1 do
      local offset = (i - startIndex) * WASTE_OFFSET
      
      if x >= self.x + offset and x <= self.x + offset + CARD_WIDTH and
         y >= self.y and y <= self.y + CARD_HEIGHT then
        return #self.cards  
      end
    end
  else
    if #self.cards > 0 and
       x >= self.x and x <= self.x + self.width and
       y >= self.y and y <= self.y + self.height then
      return #self.cards
    end
  end

  return 0
end


function PileClass:isPointInside(x, y)

  local pileBottom = self.y + self.height

  if self.pileType == PILE_TYPE.TABLEAU and #self.cards > 0 then
    pileBottom = self.y + (#self.cards - 1) * VERTICAL_SPACING + self.height
  elseif self.pileType == PILE_TYPE.WASTE and #self.cards > 0 then
    local visibleCards = math.min(3, #self.cards)
    local totalWidth = self.width + (visibleCards - 1) * WASTE_OFFSET
    
    return x >= self.x and x <= self.x + totalWidth and
           y >= self.y and y <= self.y + self.height
  end
  
  return x >= self.x and x <= self.x + self.width and
         y >= self.y and y <= pileBottom
end


function PileClass:ensureTopCardFaceUp()
  if #self.cards > 0 and not self.cards[#self.cards].faceUp then
    self.cards[#self.cards].faceUp = true
  end
end

function love.load()
  math.randomseed(os.time())
  love.window.setMode(960, 640)
  love.graphics.setBackgroundColor(0, 0.7, 0.2, 1)
    
  CardClass.loadImages()
   
  grabber = GrabberClass:new()
  
  initializeGame()
end

function initializeGame()
  math.randomseed(os.time())
  

  local deck = {}
  for _, suit in ipairs(SUITS) do
    for _, value in ipairs(VALUES) do
      table.insert(deck, CardClass:new(0, 0, suit, value))
    end
  end
  

  for i = #deck, 2, -1 do
    local j = math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end
  local totalTableauWidth = (7 * CARD_WIDTH) + (6 * HORIZONTAL_SPACING)
  local firstPileX = (960 - totalTableauWidth) / 2

  stockPile = PileClass:new(50, 50, PILE_TYPE.STOCK)
  wastePile = PileClass:new(200, 50, PILE_TYPE.WASTE)
  
  local foundationPositions = {}
  for i = 1, 4 do
    table.insert(foundationPositions, {
      x = firstPileX + (i+1) * (CARD_WIDTH + HORIZONTAL_SPACING),
      y = 50
    })
  end

  for i = #foundationPositions, 2, -1 do
    local j = math.random(i)
    foundationPositions[i], foundationPositions[j] = foundationPositions[j], foundationPositions[i]
  end

  foundationPiles = {}
  for i = 1, 4 do
    foundationPiles[i] = PileClass:new(
      foundationPositions[i].x,
      foundationPositions[i].y,
      PILE_TYPE.FOUNDATION
    )
  end

  tableauPiles = {}
  for i = 1, 7 do
    tableauPiles[i] = PileClass:new(
      firstPileX + (i-1) * (CARD_WIDTH + HORIZONTAL_SPACING),
      180,  
      PILE_TYPE.TABLEAU
    )
  end

  for i = 1, 7 do
    for j = 1, i do
      local card = table.remove(deck)
      if j == i then
        card:flip()
      end
      tableauPiles[i]:addCard(card)
    end
  end
  
  for _, card in ipairs(deck) do
    stockPile:addCard(card)
  end
  deck = nil

  draggedCards = {}
  dragOriginPile = nil
end

function love.update(dt)
  grabber:update()
  
  stockPile:update()
  wastePile:update()
  
  for _, pile in ipairs(foundationPiles) do
    pile:update()
  end
  
  for _, pile in ipairs(tableauPiles) do
    pile:update()
  end
  
  updateDrag()
  
  if not grabber.isDragging then
    checkForMouseInteractions()
  end
  
  if not gameOver then
    checkForGameOver()
  end
end

function love.draw()
  stockPile:draw()
  wastePile:draw()

  for _, pile in ipairs(foundationPiles) do
    pile:draw()
  end

  for _, pile in ipairs(tableauPiles) do
    pile:draw()
  end

  for _, card in ipairs(draggedCards) do
    card:draw()
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("Mouse: " .. tostring(grabber.currentMousePos.x) .. ", " .. tostring(grabber.currentMousePos.y), 10, 10)

  love.graphics.setColor(1, 0, 0, 0.3)
  for _, pile in ipairs(tableauPiles) do
    local pileBottom = pile.y + pile.height
    if #pile.cards > 0 then
      pileBottom = pile.y + (#pile.cards - 1) * VERTICAL_SPACING + pile.height
    end
    love.graphics.rectangle("line", pile.x, pile.y, pile.width, pileBottom - pile.y)
  end
  love.graphics.setColor(1, 1, 1, 1)

  if #draggedCards > 0 then
    love.graphics.setColor(0, 1, 0, 0.2)
    for _, pile in ipairs(tableauPiles) do
      if canPlaceCards(draggedCards, pile) then
        love.graphics.rectangle("fill", pile.x - 5, pile.y - 5, pile.width + 10, pile.height + 10, 5)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  if #stockPile.cards == 0 and #wastePile.cards > 0 then
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print(" DECK", stockPile.x + 10, stockPile.y + 50)
    love.graphics.setColor(1, 1, 1, 1)
  end
  
  if gameOver then
    love.graphics.setColor(1, 1, 1)
    local message = "You Win!"
    local textWidth = love.graphics.getFont():getWidth(message)
    message = "Press R to restart the game"
    textWidth = love.graphics.getFont():getWidth(message)
    local textHeight = love.graphics.getFont():getHeight()
    love.graphics.print(message, (love.graphics.getWidth() - textWidth) / 2, (love.graphics.getHeight() - textHeight) / 2)
  end

end


function safeCardOffset(x, y, card)
  if card and type(card.x) == "number" and type(card.y) == "number" then
    return x - card.x, y - card.y
  else
    return 0, 0
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end

  draggedCards = {}
  dragOriginPile = nil

  if stockPile:isPointInside(x, y) then
    if #stockPile.cards > 0 then
      drawFromStock()
    elseif #wastePile.cards > 0 then
      resetStockFromWaste()
    end
    return
  end

  
  if #wastePile.cards > 0 and wastePile:isPointInside(x, y) then
   local cardIndex = wastePile:findCardAt(x, y)
  
  if cardIndex > 0 then
    local card = wastePile:getTopCard()
    local offsetX, offsetY = safeCardOffset(x, y, card)
    
    local removedCard = wastePile:removeTopCard()
    if removedCard then
      table.insert(draggedCards, removedCard)
      dragOriginPile = wastePile
      for _, c in ipairs(draggedCards) do
        c.originalX, c.originalY = c.x, c.y
      end
      
      if #wastePile.cards < 3 and #stockPile.cards > 0 then
        local cardsNeeded = 3 - #wastePile.cards
        for i = 1, cardsNeeded do
          local stockCard = stockPile:removeTopCard()
          if not stockCard then break end
          stockCard:flip()
          wastePile:addCard(stockCard)
        end
      end
      
      grabber:startDrag(x, y, offsetX, offsetY)
    end
    return
  end
end

  for _, pile in ipairs(foundationPiles) do
    if #pile.cards > 0 and pile:isPointInside(x, y) then
      local card = pile:getTopCard()
      if card and card:isPointInside(x, y) then
        local offsetX, offsetY = safeCardOffset(x, y, card)
        local removedCard = pile:removeTopCard()
        if removedCard then
          table.insert(draggedCards, removedCard)
          dragOriginPile = pile
          for _, c in ipairs(draggedCards) do
            c.originalX, c.originalY = c.x, c.y
          end
          grabber:startDrag(x, y, offsetX, offsetY)
        end
        return
      end
    end
  end

  for _, pile in ipairs(tableauPiles) do
    if #pile.cards > 0 then
      local cardIndex = pile:findCardAt(x, y)
      if cardIndex > 0 and pile.cards[cardIndex].faceUp then
        local topCard = pile.cards[cardIndex]
        local offsetX, offsetY = safeCardOffset(x, y, topCard)
        local cardsToMove = pile:removeCards(cardIndex)

        if cardsToMove and #cardsToMove > 0 then
          for _, c in ipairs(cardsToMove) do
            table.insert(draggedCards, c)
          end
          dragOriginPile = pile
          for _, c in ipairs(draggedCards) do
            c.originalX, c.originalY = c.x, c.y
          end
          grabber:startDrag(x, y, offsetX, offsetY)
        end
        return
      end
    end
  end
end



function love.mousereleased(x, y, button)
  if button == 1 and #draggedCards > 0 then
    local targetPile = nil
    local closestDist = math.huge

    if #draggedCards == 1 and draggedCards[1] then
      local card = draggedCards[1]
      if card.value == 1 then
        for _, pile in ipairs(foundationPiles) do
          if #pile.cards == 0 then
            local pileCenterX = pile.x + pile.width / 2
            local pileCenterY = pile.y + pile.height / 2
            local dist = math.sqrt((x - pileCenterX)^2 + (y - pileCenterY)^2)
            if dist < closestDist then
              closestDist = dist
              targetPile = pile
            end
          end
        end
      end
      if not targetPile then
        for _, pile in ipairs(foundationPiles) do
          if #pile.cards > 0 and canPlaceCards(draggedCards, pile) then
            local pileCenterX = pile.x + pile.width / 2
            local pileCenterY = pile.y + pile.height / 2
            local dist = math.sqrt((x - pileCenterX)^2 + (y - pileCenterY)^2)
            if dist < closestDist then
              closestDist = dist
              targetPile = pile
            end
          end
        end
      end
    end

    if not targetPile then
      closestDist = math.huge
      for _, pile in ipairs(tableauPiles) do
        if canPlaceCards(draggedCards, pile) then
          local pileCenterX = pile.x + pile.width / 2
          local pileCenterY = pile.y + pile.height / 2
          local dist = math.sqrt((x - pileCenterX)^2 + (y - pileCenterY)^2)
          if dist < closestDist then
            closestDist = dist
            targetPile = pile
          end
        end
      end
    end

    if targetPile then
      if cardPlaceSound then
        cardPlaceSound:stop()
        cardPlaceSound:play()
      end
      for _, card in ipairs(draggedCards) do
        if card then
          targetPile:addCard(card)
        end
      end
      if dragOriginPile and dragOriginPile.pileType == PILE_TYPE.TABLEAU and #dragOriginPile.cards > 0 then
        local topCard = dragOriginPile.cards[#dragOriginPile.cards]
        if topCard and not topCard.faceUp then
          topCard.faceUp = true
        end
      end
    else
      if dragOriginPile then
        for _, card in ipairs(draggedCards) do
          if card then
            dragOriginPile:addCard(card)
          end
        end
      end
    end

    draggedCards = {}
    grabber:endDrag()
  end
end


function updateDrag()
  if grabber and grabber.isDragging and #draggedCards > 0 and 
     grabber.currentMousePos and type(grabber.currentMousePos.x) == "number" and 
     type(grabber.currentMousePos.y) == "number" and
     grabber.dragOffset and type(grabber.dragOffset.x) == "number" and 
     type(grabber.dragOffset.y) == "number" then
    
    local mouseX = grabber.currentMousePos.x
    local mouseY = grabber.currentMousePos.y
    
    for i, card in ipairs(draggedCards) do
      if card then
        card.x = mouseX - grabber.dragOffset.x
        card.y = mouseY - grabber.dragOffset.y + (i-1) * VERTICAL_SPACING 
      end
    end
  end
end


function checkForMouseInteractions()
  local mouseX = grabber.currentMousePos.x
  local mouseY = grabber.currentMousePos.y
  local isOverCard = false

  if stockPile:isPointInside(mouseX, mouseY) then
    isOverCard = true
  end

  if wastePile:isPointInside(mouseX, mouseY) then
    isOverCard = true
  end

  for _, pile in ipairs(foundationPiles) do
    if pile:isPointInside(mouseX, mouseY) then
      isOverCard = true
      break
    end
  end

  for _, pile in ipairs(tableauPiles) do
    if pile:findCardAt(mouseX, mouseY) > 0 then
      isOverCard = true
      break
    end
  end

  if isOverCard then
    love.mouse.setCursor(love.mouse.getSystemCursor("hand"))
  else
    love.mouse.setCursor()
  end
end

function drawFromStock()
  local cardsToDraw = math.min(3, #stockPile.cards)
  local cardsToMove = {}

  for i = 1, cardsToDraw do
    local card = stockPile:removeTopCard()
    if card then
      card:flip()
      table.insert(cardsToMove, card)
    end
  end

  for i = #cardsToMove, 2, -1 do
    local j = math.random(i)
    cardsToMove[i], cardsToMove[j] = cardsToMove[j], cardsToMove[i]
  end

  for _, card in ipairs(cardsToMove) do
    wastePile:addCard(card)
  end
end


function resetStockFromWaste()
  while #wastePile.cards > 0 do
    local card = wastePile:removeTopCard()
    card:flip() 
    stockPile:addCard(card)
  end
end

function canPlaceCards(cards, targetPile)
  if #cards == 0 then return false end

  local bottomCard = cards[1]
  if not bottomCard then return false end

  if targetPile.pileType == PILE_TYPE.FOUNDATION then
    if #cards > 1 then return false end

    if #targetPile.cards == 0 then
      return bottomCard.value == 1
    end

    local topCard = targetPile:getTopCard()
    if not topCard then return false end

    return bottomCard.suit == topCard.suit and
           bottomCard.value == topCard.value + 1
  end

  if targetPile.pileType == PILE_TYPE.TABLEAU then
    local topCard = targetPile:getTopCard()

    if not topCard then
      return bottomCard.value == 13
    end

    local bottomIsRed = bottomCard.suit == "hearts" or bottomCard.suit == "diamonds"
    local topIsRed = topCard.suit == "hearts" or topCard.suit == "diamonds"

    return bottomIsRed ~= topIsRed and
           bottomCard.value == topCard.value - 1
  end

  return false
end

function checkForGameOver()
  for _, pile in ipairs(foundationPiles) do
    if #pile.cards < 13 then
      return 
    end
  end
  gameOver = true
end


function love.keypressed(key)
  if key == "r" and gameOver then
    gameOver = false
    initializeGame()
  end
end
