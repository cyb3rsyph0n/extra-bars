-- !ExtraBars Bar
-- Bar creation, button handling, and Edit Mode integration

local addonName, ExtraBars = ...

-- Create the main bar frame with Edit Mode support
function ExtraBars:CreateBar(barID, barData)
    if self.barFrames[barID] then
        return self.barFrames[barID]
    end
    
    local bar = CreateFrame("Frame", "ExtraBarsBar" .. barID, UIParent, "BackdropTemplate")
    bar.barID = barID
    bar.buttons = {}
    
    -- Set frame strata from settings
    local strata = barData.strata or "MEDIUM"
    bar:SetFrameStrata(strata)
    
    -- Set up backdrop (invisible by default, shown in edit mode)
    bar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    bar:SetBackdropColor(0, 0, 0, 0)
    bar:SetBackdropBorderColor(0, 0, 0, 0)
    
    -- Create bar label (shown in edit mode)
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.label:SetPoint("TOP", bar, "TOP", 0, 15)
    bar.label:SetText(self:GetBarDisplayName(barID))
    bar.label:Hide()
    
    -- Make bar movable
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(false)
    
    self.barFrames[barID] = bar
    
    -- Register with Edit Mode system
    self:RegisterBarWithEditMode(barID, bar)
    
    -- Update the bar with current settings
    self:UpdateBar(barID)
    self:UpdateBarPosition(barID)
    
    return bar
end

-- Register a bar frame with WoW's Edit Mode system
function ExtraBars:RegisterBarWithEditMode(barID, bar)
    -- Create the edit mode selection frame that wraps the bar
    local selection = CreateFrame("Frame", bar:GetName() .. "Selection", bar, "EditModeSystemSelectionTemplate")
    selection:SetAllPoints(bar)
    selection:SetFrameLevel(bar:GetFrameLevel() + 100)
    selection.barID = barID
    bar.Selection = selection
    
    -- Set up the highlight/selection textures
    if selection.HighlightFrame then
        selection.HighlightFrame:SetAllPoints(bar)
    end
    if selection.SelectionFrame then
        selection.SelectionFrame:SetAllPoints(bar)
    end
    
    -- Label for edit mode
    selection.Label = selection:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    selection.Label:SetPoint("TOP", selection, "TOP", 0, 20)
    selection.Label:SetText("|cff00ff00" .. ExtraBars:GetBarDisplayName(barID) .. "|r")
    
    -- Make it draggable in edit mode
    selection:SetMovable(true)
    selection:RegisterForDrag("LeftButton")
    selection:EnableMouse(true)
    
    selection:SetScript("OnDragStart", function(self)
        if ExtraBars:IsEditModeActive() then
            bar:StartMoving()
        end
    end)
    
    selection:SetScript("OnDragStop", function(self)
        bar:StopMovingOrSizing()
        ExtraBars:SaveBarPosition(barID)
    end)
    
    selection:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and ExtraBars:IsEditModeActive() then
            ExtraBars:SelectBar(barID)
        end
    end)
    
    selection:SetScript("OnEnter", function(self)
        if ExtraBars:IsEditModeActive() then
            -- Show highlight border on hover
            if selection.ShowHighlighted then
                selection:ShowHighlighted()
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ExtraBars:GetBarDisplayName(barID), 1, 1, 1)
            GameTooltip:AddLine("Click to select, drag to move", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Use /eb to configure categories", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    
    selection:SetScript("OnLeave", function(self)
        -- Hide highlight when not hovering
        if selection.HideHighlighted then
            selection:HideHighlighted()
        end
        GameTooltip:Hide()
    end)
    
    -- Initially hide - shown only in Edit Mode
    selection:Hide()
    
    -- If we're already in edit mode, show the selection frame immediately
    if self:IsEditModeActive() then
        selection:Show()
        bar.label:Show()
        bar:SetBackdropColor(0, 0, 0, 0.3)
        bar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    end
    
    -- Hook into Edit Mode events
    if not self.editModeHooked then
        self:HookEditModeEvents()
    end
end

-- Hook into the game's Edit Mode events
function ExtraBars:HookEditModeEvents()
    if self.editModeHooked then return end
    self.editModeHooked = true
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    eventFrame:SetScript("OnEvent", function(self, event)
        ExtraBars:UpdateEditModeState()
    end)
    
    -- Also hook the EditModeManagerFrame if available
    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
            ExtraBars:OnEnterEditMode()
        end)
        
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            ExtraBars:OnExitEditMode()
        end)
    end
end

-- Called when entering Edit Mode
function ExtraBars:OnEnterEditMode()
    for barID, bar in pairs(self.barFrames) do
        if bar and bar.Selection then
            local barData = self.db.bars[barID]
            
            -- Update bar first to ensure correct sizing
            self:UpdateBar(barID)
            
            -- Refresh the selection frame to match bar size
            bar.Selection:ClearAllPoints()
            bar.Selection:SetAllPoints(bar)
            if bar.Selection.HighlightFrame then
                bar.Selection.HighlightFrame:ClearAllPoints()
                bar.Selection.HighlightFrame:SetAllPoints(bar)
            end
            if bar.Selection.SelectionFrame then
                bar.Selection.SelectionFrame:ClearAllPoints()
                bar.Selection.SelectionFrame:SetAllPoints(bar)
            end
            
            -- Show selection frame with blue highlight
            bar.Selection:Show()
            bar.Selection.Label:SetText("|cff00ff00" .. self:GetBarDisplayName(barID) .. "|r")
            
            -- Show the blue highlight border (native Edit Mode style)
            if bar.Selection.ShowHighlighted then
                bar.Selection:ShowHighlighted()
            end
            
            -- Show bar label
            bar.label:Show()
            bar.label:SetText(self:GetBarDisplayName(barID))
            
            -- Ensure minimum size for empty bars
            local width, height = bar:GetSize()
            if width < 60 or height < 40 then
                bar:SetSize(math.max(width, 80), math.max(height, 50))
            end
        end
    end
end

-- Called when exiting Edit Mode
function ExtraBars:OnExitEditMode()
    for barID, bar in pairs(self.barFrames) do
        if bar and bar.Selection then
            -- Hide selection frame and highlight
            if bar.Selection.HideHighlighted then
                bar.Selection:HideHighlighted()
            end
            bar.Selection:Hide()
            
            -- Hide bar label
            bar.label:Hide()
            
            -- Recalculate proper size
            self:UpdateBar(barID)
        end
    end
    
    -- Close config panel when exiting Edit Mode
    if self.configPanel and self.configPanel:IsShown() then
        self.configPanel:Hide()
    end
end

-- Update edit mode state based on current mode
function ExtraBars:UpdateEditModeState()
    if self:IsEditModeActive() then
        self:OnEnterEditMode()
    else
        self:OnExitEditMode()
    end
end

-- Create a single button for the bar
function ExtraBars:CreateButton(bar, index, iconSize)
    local button = CreateFrame("Button", bar:GetName() .. "Button" .. index, bar, "SecureActionButtonTemplate, BackdropTemplate")
    button:SetSize(iconSize, iconSize)
    
    -- Set up button visuals
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    
    button.cooldown = CreateFrame("Cooldown", button:GetName() .. "Cooldown", button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetDrawBling(false)
    
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button.count:SetJustifyH("RIGHT")
    
    -- No highlight - flat icon appearance
    
    -- Set up tooltip
    button:SetScript("OnEnter", function(self)
        if self.itemType and self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.itemType == "SPELL" then
                GameTooltip:SetSpellByID(self.itemID)
            elseif self.itemType == "ITEM" then
                GameTooltip:SetItemByID(self.itemID)
            end
            GameTooltip:Show()
        end
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return button
end

-- Update a bar's buttons and layout
function ExtraBars:UpdateBar(barID)
    local barData = self.db.bars[barID]
    local bar = self.barFrames[barID]
    
    if not barData or not bar then return end
    
    -- Show/hide bar based on enabled state
    if not barData.enabled then
        bar:Hide()
        return
    end
    
    -- Get available items for this bar
    local items = self:GetAllAvailableItemsForBar(barID)
    
    -- Update bar label with display name
    local displayName = self:GetBarDisplayName(barID)
    bar.label:SetText(displayName)
    if bar.Selection and bar.Selection.Label then
        bar.Selection.Label:SetText("|cff00ff00" .. displayName .. "|r")
    end
    
    local iconSize = barData.iconSize
    local padding = barData.iconPadding
    local rows = barData.rows
    local cols = barData.cols
    local maxButtons = rows * cols
    
    -- Hide existing buttons
    for i, button in ipairs(bar.buttons) do
        button:Hide()
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("item", nil)
    end
    
    -- Create or update buttons
    local buttonIndex = 0
    for i, item in ipairs(items) do
        if buttonIndex >= maxButtons then break end
        
        buttonIndex = buttonIndex + 1
        
        -- Create button if needed
        if not bar.buttons[buttonIndex] then
            bar.buttons[buttonIndex] = self:CreateButton(bar, buttonIndex, iconSize)
        end
        
        local button = bar.buttons[buttonIndex]
        button:SetSize(iconSize, iconSize)
        button.itemID = item.id
        button.itemType = item.type
        button.isPlaceholder = nil
        
        -- Position button in grid based on anchor
        local row = math.floor((buttonIndex - 1) / cols)
        local col = (buttonIndex - 1) % cols
        -- Handle legacy data where anchor might be a table or missing
        local anchor = barData.anchor
        if type(anchor) ~= "string" then
            anchor = "TOPLEFT"
        end
        local xOffset, yOffset
        local anchorPoint
        
        if anchor == "TOPLEFT" then
            xOffset = col * (iconSize + padding) + padding
            yOffset = -row * (iconSize + padding) - padding
            anchorPoint = "TOPLEFT"
        elseif anchor == "TOPRIGHT" then
            xOffset = -col * (iconSize + padding) - padding
            yOffset = -row * (iconSize + padding) - padding
            anchorPoint = "TOPRIGHT"
        elseif anchor == "BOTTOMLEFT" then
            xOffset = col * (iconSize + padding) + padding
            yOffset = row * (iconSize + padding) + padding
            anchorPoint = "BOTTOMLEFT"
        elseif anchor == "BOTTOMRIGHT" then
            xOffset = -col * (iconSize + padding) - padding
            yOffset = row * (iconSize + padding) + padding
            anchorPoint = "BOTTOMRIGHT"
        else
            -- Default fallback
            anchor = "TOPLEFT"
            xOffset = col * (iconSize + padding) + padding
            yOffset = -row * (iconSize + padding) - padding
            anchorPoint = "TOPLEFT"
        end
        
        button:ClearAllPoints()
        button:SetPoint(anchorPoint, bar, anchorPoint, xOffset, yOffset)
        
        -- Set up button attributes and visuals
        if item.type == "SPELL" then
            button:SetAttribute("type", "spell")
            button:SetAttribute("spell", item.id)
            
            local spellInfo = C_Spell.GetSpellInfo(item.id)
            if spellInfo then
                button.icon:SetTexture(spellInfo.iconID)
            end
            button.count:SetText("")
            button.slotID = nil
            
            -- Update cooldown
            self:UpdateButtonCooldown(button, "SPELL", item.id)
            
            -- Spells are always available if shown
            button.icon:SetDesaturated(false)
            button.icon:SetVertexColor(1, 1, 1)
            
        elseif item.type == "ITEM" then
            -- Check if this item is unavailable (custom item that player ran out of)
            local isUnavailable = item.unavailable
            
            -- Check if this is an equipped item (trinket)
            if item.slotID then
                -- Use slot-based action for equipped items
                button:SetAttribute("type", "macro")
                button:SetAttribute("macrotext", "/use " .. item.slotID)
                button.slotID = item.slotID
            elseif isUnavailable then
                -- Unavailable item - disable interaction
                button:SetAttribute("type", nil)
                button:SetAttribute("item", nil)
                button.slotID = nil
            else
                button:SetAttribute("type", "item")
                button:SetAttribute("item", "item:" .. item.id)
                button.slotID = nil
            end
            
            local itemIcon = C_Item.GetItemIconByID(item.id)
            if itemIcon then
                button.icon:SetTexture(itemIcon)
            end
            
            -- Grey out unavailable items
            if isUnavailable then
                button.icon:SetDesaturated(true)
                button.icon:SetVertexColor(0.5, 0.5, 0.5)
            else
                button.icon:SetDesaturated(false)
                button.icon:SetVertexColor(1, 1, 1)
            end
            
            -- Update count (don't show for equipped items)
            if item.slotID then
                button.count:SetText("")
            else
                local count = C_Item.GetItemCount(item.id, true, false)
                if count > 1 then
                    button.count:SetText(count)
                elseif isUnavailable then
                    button.count:SetText("0")
                    button.count:SetTextColor(1, 0.3, 0.3) -- Red color for 0 count
                else
                    button.count:SetText("")
                end
            end
            
            -- Reset count color for available items
            if not isUnavailable then
                button.count:SetTextColor(1, 1, 1)
            end
            
            -- Update cooldown
            self:UpdateButtonCooldown(button, "ITEM", item.id)
        end
        
        button:Show()
    end
    
    -- If no items, show a placeholder button
    if buttonIndex == 0 then
        buttonIndex = 1
        
        -- Create placeholder button if needed
        if not bar.buttons[1] then
            bar.buttons[1] = self:CreateButton(bar, 1, iconSize)
        end
        
        local button = bar.buttons[1]
        button:SetSize(iconSize, iconSize)
        button.itemID = nil
        button.itemType = nil
        button.slotID = nil
        
        -- Clear any attributes
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("item", nil)
        button:SetAttribute("macrotext", nil)
        
        -- Position placeholder at the anchor point
        local anchor = barData.anchor
        if type(anchor) ~= "string" then
            anchor = "TOPLEFT"
        end
        local anchorPoint = anchor
        local xOffset = padding
        local yOffset = -padding
        if anchor == "TOPRIGHT" then
            xOffset = -padding
            yOffset = -padding
        elseif anchor == "BOTTOMLEFT" then
            xOffset = padding
            yOffset = padding
        elseif anchor == "BOTTOMRIGHT" then
            xOffset = -padding
            yOffset = padding
        end
        
        button:ClearAllPoints()
        button:SetPoint(anchorPoint, bar, anchorPoint, xOffset, yOffset)
        
        -- Set placeholder appearance (question mark icon)
        button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        button.count:SetText("")
        button.cooldown:Clear()
        button.isPlaceholder = true
        
        button:Show()
    end
    
    -- Calculate bar size
    local usedCols = math.min(buttonIndex, cols)
    local usedRows = math.ceil(buttonIndex / cols)
    
    if usedCols == 0 then usedCols = 1 end
    if usedRows == 0 then usedRows = 1 end
    
    local barWidth = usedCols * (iconSize + padding) + padding
    local barHeight = usedRows * (iconSize + padding) + padding
    
    bar:SetSize(barWidth, barHeight)
    bar:Show()
    
    -- Start update timer for cooldowns and counts
    self:StartBarUpdateTimer(barID)
end

-- Update button cooldown display
function ExtraBars:UpdateButtonCooldown(button, itemType, itemID)
    if not button.cooldown then return end
    
    local start, duration = 0, 0
    local inCombat = InCombatLockdown()
    
    if not inCombat then
        -- Outside combat: query actual values and cache them
        if itemType == "SPELL" then
            local cooldownInfo = C_Spell.GetSpellCooldown(itemID)
            if cooldownInfo and type(cooldownInfo.startTime) == "number" and type(cooldownInfo.duration) == "number" then
                start = cooldownInfo.startTime
                duration = cooldownInfo.duration
            end
            -- Cache the base cooldown duration from spell data (in milliseconds, convert to seconds)
            local baseCooldown = GetSpellBaseCooldown(itemID)
            if baseCooldown and baseCooldown > 1500 then  -- Ignore GCD (1.5s = 1500ms)
                button.baseCDDuration = baseCooldown / 1000
            elseif duration > 1.5 then
                -- Fall back to actual cooldown duration if base cooldown not available
                button.baseCDDuration = duration
            end
        elseif itemType == "ITEM" then
            local itemStart, itemDuration = C_Item.GetItemCooldown(itemID)
            if type(itemStart) == "number" and type(itemDuration) == "number" then
                start = itemStart
                duration = itemDuration
            end
            -- Cache the spell ID that this item casts (for detecting use during combat)
            local itemSpellID = select(1, C_Item.GetItemSpell(itemID))
            if itemSpellID then
                button.itemSpellID = itemSpellID
                -- Try to get the base cooldown from the item's spell
                local baseCooldown = GetSpellBaseCooldown and GetSpellBaseCooldown(itemSpellID)
                if baseCooldown and baseCooldown > 1500 then  -- Ignore GCD
                    button.baseCDDuration = baseCooldown / 1000
                elseif duration > 1.5 then
                    -- Fall back to actual cooldown duration if base cooldown not available
                    button.baseCDDuration = duration
                else
                    -- Default to 5 minutes for potions/consumables if no other data
                    button.baseCDDuration = 300
                end
            elseif duration > 1.5 then
                -- No spell ID but we have a cooldown duration, cache it
                button.baseCDDuration = duration
            else
                -- Default fallback for consumables
                button.baseCDDuration = 300
            end
        end
        
        -- Cache the current cooldown values on the button
        button.cachedCDStart = start
        button.cachedCDDuration = duration
    else
        -- During combat: use cached values if available
        if button.cachedCDStart and button.cachedCDDuration then
            start = button.cachedCDStart
            duration = button.cachedCDDuration
            
            -- Check if the cached cooldown has expired
            local now = GetTime()
            if start > 0 and duration > 0 and (now >= start + duration) then
                -- Cooldown has expired, clear it
                start = 0
                duration = 0
                button.cachedCDStart = 0
                button.cachedCDDuration = 0
            end
        end
    end
    
    -- Use pcall to safely handle WoW's "secret values" that can't be compared
    local success, shouldShowCooldown = pcall(function()
        return start > 0 and duration > 0
    end)
    
    if success and shouldShowCooldown then
        button.cooldown:SetCooldown(start, duration)
    else
        button.cooldown:Clear()
    end
end

-- Start a timer to update bar cooldowns and item counts
function ExtraBars:StartBarUpdateTimer(barID)
    local bar = self.barFrames[barID]
    if not bar then return end
    
    if bar.updateTimer then
        bar.updateTimer:Cancel()
    end
    
    bar.updateTimer = C_Timer.NewTicker(0.1, function()
        if not ExtraBars.barFrames[barID] then
            return
        end
        ExtraBars:UpdateBarCooldownsAndCounts(barID)
    end)
end

-- Update cooldowns and item counts for a bar
function ExtraBars:UpdateBarCooldownsAndCounts(barID)
    local bar = self.barFrames[barID]
    if not bar then return end
    
    local inCombat = InCombatLockdown()
    
    for _, button in ipairs(bar.buttons) do
        if button:IsShown() and button.itemID and button.itemType then
            -- Update cooldown (uses cached values during combat)
            self:UpdateButtonCooldown(button, button.itemType, button.itemID)
            
            -- Update count for items (skip during combat as GetItemCount may return protected values)
            if not inCombat and button.itemType == "ITEM" then
                local count = C_Item.GetItemCount(button.itemID, true, false)
                -- Cache the count for detecting usage during combat
                button.cachedItemCount = count
                if count > 1 then
                    button.count:SetText(count)
                elseif count == 0 then
                    button:SetAlpha(0.5)
                    button.count:SetText("")
                else
                    button:SetAlpha(1)
                    button.count:SetText("")
                end
            end
        end
    end
end

-- Get the anchor point based on anchor setting (handles legacy data)
function ExtraBars:GetAnchorPoint(anchor)
    -- Handle legacy data where anchor might be a table
    if type(anchor) ~= "string" then
        return "TOPLEFT"
    end
    -- Anchor is already the point name
    if anchor == "TOPLEFT" or anchor == "TOPRIGHT" or anchor == "BOTTOMLEFT" or anchor == "BOTTOMRIGHT" then
        return anchor
    end
    return "TOPLEFT" -- Default
end

-- Convert bar position from current anchor to new anchor (keeps bar in same screen position)
function ExtraBars:ConvertAnchorPosition(barID, newAnchor)
    local barData = self.db.bars[barID]
    local bar = self.barFrames[barID]
    
    if not barData or not bar then return end
    
    -- Get the bar's current screen rectangle
    local left, bottom, width, height = bar:GetRect()
    if not left then return end
    
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    
    -- Calculate new offsets based on the NEW anchor point
    local newXOfs, newYOfs
    if newAnchor == "TOPLEFT" then
        newXOfs = left
        newYOfs = (bottom + height) - screenHeight
    elseif newAnchor == "TOPRIGHT" then
        newXOfs = (left + width) - screenWidth
        newYOfs = (bottom + height) - screenHeight
    elseif newAnchor == "BOTTOMLEFT" then
        newXOfs = left
        newYOfs = bottom
    elseif newAnchor == "BOTTOMRIGHT" then
        newXOfs = (left + width) - screenWidth
        newYOfs = bottom
    else
        return -- Invalid anchor
    end
    
    -- Update position data for the new anchor
    barData.position = {
        point = newAnchor,
        relativePoint = newAnchor,
        xOffset = newXOfs,
        yOffset = newYOfs,
    }
end

-- Save bar position after dragging (using anchor-aware positioning)
function ExtraBars:SaveBarPosition(barID)
    local barData = self.db.bars[barID]
    local bar = self.barFrames[barID]
    
    if not barData or not bar then return end
    
    -- Get the appropriate anchor point for the bar's anchor setting
    local anchorPoint = self:GetAnchorPoint(barData.anchor)
    
    -- Get the current anchor point info from the frame
    local point, relativeTo, relativePoint, xOfs, yOfs = bar:GetPoint(1)
    if not point then return end
    
    -- If the current point matches our desired anchor, just save it directly
    if point == anchorPoint then
        barData.position = {
            point = point,
            relativePoint = relativePoint,
            xOffset = xOfs,
            yOffset = yOfs,
        }
    else
        -- Convert position from current point to desired anchor point
        local left, bottom, width, height = bar:GetRect()
        if not left then return end
        
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        
        -- Calculate new offsets based on desired anchor
        local newXOfs, newYOfs
        if anchorPoint == "TOPLEFT" then
            newXOfs = left
            newYOfs = (bottom + height) - screenHeight
        elseif anchorPoint == "TOPRIGHT" then
            newXOfs = (left + width) - screenWidth
            newYOfs = (bottom + height) - screenHeight
        elseif anchorPoint == "BOTTOMLEFT" then
            newXOfs = left
            newYOfs = bottom
        elseif anchorPoint == "BOTTOMRIGHT" then
            newXOfs = (left + width) - screenWidth
            newYOfs = bottom
        end
        
        barData.position = {
            point = anchorPoint,
            relativePoint = anchorPoint,
            xOffset = newXOfs,
            yOffset = newYOfs,
        }
    end
end

-- Update bar position based on saved position (anchor-aware)
function ExtraBars:UpdateBarPosition(barID)
    local barData = self.db.bars[barID]
    local bar = self.barFrames[barID]
    
    if not barData or not bar then return end
    
    -- Get the appropriate anchor for the current anchor setting
    local anchorPoint = self:GetAnchorPoint(barData.anchor)
    
    bar:ClearAllPoints()
    
    local pos = barData.position
    
    -- Ensure position data exists and has valid values
    if not pos or pos.xOffset == nil or pos.yOffset == nil then
        -- Use default centered position if no valid position saved
        pos = self:GetDefaultPosition()
        barData.position = pos
    end
    
    -- Apply the saved position using the anchor point
    bar:SetPoint(anchorPoint, UIParent, anchorPoint, pos.xOffset, pos.yOffset)
end

-- Register events for bar updates
local updateFrame = CreateFrame("Frame")
updateFrame:RegisterEvent("BAG_UPDATE")
updateFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
updateFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
updateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
updateFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
updateFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
updateFrame:RegisterEvent("BAG_UPDATE_DELAYED")

updateFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit == "player" then
            -- Always try to trigger cooldown (works both in and out of combat)
            ExtraBars:OnSpellCastSucceeded(spellID)
        end
        return
    end
    
    if event == "BAG_UPDATE_DELAYED" then
        -- When bags change during combat (e.g., potion consumed), check for items that just went on cooldown
        if InCombatLockdown() then
            ExtraBars:CheckItemCooldownsInCombat()
        end
        return
    end
    
    -- Delay update slightly to allow game state to settle
    C_Timer.After(0.1, function()
        -- Skip updates during combat to avoid secret value errors
        -- PLAYER_REGEN_ENABLED will trigger a full refresh when combat ends
        if InCombatLockdown() then
            return
        end
        ExtraBars:UpdateAllBars()
    end)
end)

-- Check if any items just went on cooldown during combat (for potions, etc.)
function ExtraBars:CheckItemCooldownsInCombat()
    local now = GetTime()
    
    for barID, bar in pairs(self.barFrames) do
        if bar.buttons then
            for _, button in ipairs(bar.buttons) do
                if button.itemType == "ITEM" and button.itemID and button.baseCDDuration then
                    -- Check if item count decreased (item was consumed)
                    local currentCount = C_Item.GetItemCount(button.itemID, true, false)
                    local previousCount = button.cachedItemCount or 0
                    
                    if currentCount < previousCount then
                        -- Item was consumed, start cooldown
                        if button.baseCDDuration > 1.5 then
                            button.cachedCDStart = now
                            button.cachedCDDuration = button.baseCDDuration
                            button.cooldown:SetCooldown(now, button.baseCDDuration)
                        end
                        -- Update cached count
                        button.cachedItemCount = currentCount
                    end
                end
            end
        end
    end
end

-- Handle spell cast during combat - start cooldown using cached duration
function ExtraBars:OnSpellCastSucceeded(spellID)
    local now = GetTime()
    
    for barID, bar in pairs(self.barFrames) do
        if bar.buttons then
            for _, button in ipairs(bar.buttons) do
                local isMatch = false
                
                -- Check if it's a direct spell match
                if button.itemType == "SPELL" and button.itemID == spellID then
                    isMatch = true
                -- Check if it's an item that casts this spell (potions, trinkets, etc.)
                elseif button.itemType == "ITEM" and button.itemSpellID == spellID then
                    isMatch = true
                end
                
                if isMatch then
                    -- Use cached base duration if available
                    local duration = button.baseCDDuration or 0
                    if duration > 1.5 then  -- Must be more than GCD
                        button.cachedCDStart = now
                        button.cachedCDDuration = duration
                        button.cooldown:SetCooldown(now, duration)
                    end
                end
            end
        end
    end
end
