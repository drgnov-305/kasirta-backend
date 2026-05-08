local function InitTitanEnterprise()
    local HttpService = game:GetService("HttpService")
    local VirtualUser = game:GetService("VirtualUser")
    local player = game:GetService("Players").LocalPlayer
    local PlayerGui = player:WaitForChild("PlayerGui")

    -- ANTI-AFK 20 MINUTE BYPASS (SILENT CLICK, NO JUMP FOR STEALTH)
    player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    local coreGui = game:GetService("CoreGui")
    local runService = game:GetService("RunService")
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local workspace = game:GetService("Workspace")

    local WorldManager = require(replicatedStorage:WaitForChild("Managers").WorldManager)
    local Inventory = require(replicatedStorage:WaitForChild("Modules").Inventory)
    local ItemsManager = require(replicatedStorage:WaitForChild("Managers").ItemsManager)
    local UIManager = require(replicatedStorage:WaitForChild("Managers").UIManager)

    local PlayerMovement = require(player.PlayerScripts:WaitForChild("PlayerMovement"))
    local Remotes = replicatedStorage:WaitForChild("Remotes")
    local PlayerFist = Remotes:WaitForChild("PlayerFist")
    local PlayerPlaceItem = Remotes:WaitForChild("PlayerPlaceItem")
    local PlayerDrop = Remotes:WaitForChild("PlayerDrop")
    local PlayerItemTrash = Remotes:WaitForChild("PlayerItemTrash")
    local TILE_SIZE = 4.5

    if coreGui:FindFirstChild("TitanEnterpriseUI") then 
        coreGui.TitanEnterpriseUI:Destroy() 
    end

    -- ==========================================
    -- STATE MANAGER & MEMORY (BYPASS 200 LIMIT)
    -- ==========================================
    local STATE = {
        isMinimized = false,
        autoClear = false, autoFarm = false, autoY1 = false, autoDrop = false, autoLoot = false, autoMove = false, autoPlace = false,
        saplingSensorOnly = false,
        farmTargetBlock = "", placeTargetBlock = "", y1TargetBlock = "", ifTargetItem = "", 
        farmStartY = 60, farmEndY = 6, customFarmTimer = 30, 
        clearStartX = 0, clearEndX = 100, clearStartY = 60, clearEndY = 0,
        isPosLocked = false, lockedCoordX = 0, lockedCoordY = 0,
        dropCoordX = 0, dropCoordY = 0, factoryMoveX = 0, factoryMoveY = 0,
        dropConfig = {}, currentSelectionMode = nil,
        isFactoryRunning = false, factoryQueue = {}, currentFactoryIndex = 1,
        factoryLoopStartIndex = 1, factoryLoopCount = 0, factoryLoopLimit = 0, factoryStuckCounter = 0,
        activeFactoryTask = nil, factoryDropInProgress = false, factoryForceStopTask = false,
        gLootCache = {}, globalTargetLoot = nil, lootQueue = {}, lastScan = 0, lastPathCalc = 0, lastRadarScan = 0,
        radarTotalDrops = 0, reachableDrops = 0, lastBfsScannedAir = 0, lastBfsTotalAir = 0,
        placeQueue = {},
        actionQueue = {}, botPhase = "IDLE", TreeTracker = {}
    }

    local UI = {} 

    -- ==========================================
    -- UNIVERSAL AUTO-CONFIRM HOOK (DUMP ENGINE)
    -- ==========================================
    _G.TargetPromptAmount = 1 
    _G.CurrentlyProcessingInv = false

    if not _G.OriginalPrompt then
        _G.OriginalPrompt = UIManager.BuildAndShowUIPrompt
    end

    UIManager.BuildAndShowUIPrompt = function(promptConfig, callback)
        _G.OriginalPrompt(promptConfig, callback)
        
        if _G.CurrentlyProcessingInv then
            task.spawn(function()
                local promptUI = PlayerGui:WaitForChild("UIPromptUI", 2)
                if promptUI then
                    local frame = promptUI:WaitForChild("Frame", 1)
                    if frame then
                        local textBox = frame:FindFirstChild("TextBox", true)
                        local confirmBtn = nil
                        
                        for _, desc in ipairs(frame:GetDescendants()) do
                            if desc:IsA("TextButton") and desc.Name ~= "CloseButton" then
                                confirmBtn = desc; break
                            end
                        end

                        if textBox and confirmBtn then
                            textBox.Text = tostring(_G.TargetPromptAmount or "1")
                            task.wait(0.1) 
                            if getconnections then
                                for _, conn in pairs(getconnections(confirmBtn.MouseButton1Click)) do conn:Fire() end
                            elseif firesignal then
                                firesignal(confirmBtn.MouseButton1Click)
                            end
                        end
                    end
                end
            end)
        end
    end

    -- ==========================================
    -- ENGINE GLOBALS
    -- ==========================================
    _G.MagmaHits, _G.LastHitTime, _G.RegenTime = 0, 0, 0
    _G.CurrentlyBreaking, _G.PosHistory, _G.BlacklistedNodes = nil, {}, {}
    _G.CurrentSmartPath, _G.PathTargetKey, _G.PathNextStepIndex = nil, nil, 1
    _G.EscapeMode = nil
    _G.CurrentStatus = "STATUS: IDLE"
    _G.LastY1Break, _G.LastY1Jump, _G.LastSyncTime, _G.LastMultiplyPlace = 0, 0, 0, 0
    _G.PendingPlants = {} 
    _G.LastFistTime = 0
    _G.Y1EmptyTimer = nil

    -- ==========================================
    -- ANTI-NIL GET NAME FUNCTION (OPTIMIZED)
    -- ==========================================
    local function GetSafeName(node)
        if type(node) == "table" then
            return string.upper(tostring(node.Name or node.Id or node.item or "AIR"))
        elseif node ~= nil then
            return string.upper(tostring(node))
        end
        return "AIR"
    end

    -- ==========================================
    -- ABSOLUTE ITEM POSITION FETCHER (UPGRADED)
    -- ==========================================
    local function GetItemPos(item)
        if typeof(item) == "Instance" then
            if item:IsA("BasePart") then return item.Position end
            if item:IsA("Model") then
                if item.PrimaryPart then return item.PrimaryPart.Position end
                local pivot = item:GetPivot()
                if pivot then return pivot.Position end
            end
            local bp = item:FindFirstChildWhichIsA("BasePart", true)
            if bp then return bp.Position end
        end
        return nil
    end

    -- ==========================================
    -- HELPER TIME FORMATTER
    -- ==========================================
    local function FormatTimeID(seconds)
        if seconds <= 0 then return "SEKARANG / READY!" end
        local d = math.floor(seconds / 86400)
        local h = math.floor((seconds % 86400) / 3600)
        local m = math.floor((seconds % 3600) / 60)
        local s = seconds % 60
        if d > 0 then return string.format("%d Hari, %02d Jam, %02d Menit, %02d Detik", d, h, m, s) end
        if h > 0 then return string.format("%02d Jam, %02d Menit, %02d Detik", h, m, s) end
        if m > 0 then return string.format("%02d Menit, %02d Detik", m, s) end
        return string.format("%02d Detik", s)
    end

    -- ==========================================
    -- DATA FUNCTIONS
    -- ==========================================
    local function GetFullInventoryData()
        local aggregated = {}
        for slotIndex, itemData in pairs(Inventory.Stacks or {}) do
            if itemData and itemData.Id and (itemData.Amount or 0) > 0 then
                local itemName = tostring(ItemsManager.GetName(itemData.Id) or "Unknown Item")
                local itemType = "Unknown"
                
                if itemName:lower():find("sapling") or itemName:lower():find("seed") then itemType = "SAPLING"
                elseif itemName:lower():find("block") or itemName:lower():find("dirt") or itemName:lower():find("wood") then itemType = "BLOCK"
                elseif itemName:lower():find("lock") then itemType = "LOCK" end

                if not STATE.dropConfig[itemName] then STATE.dropConfig[itemName] = "IGNORE" end

                if not aggregated[itemData.Id] then
                    aggregated[itemData.Id] = { Name = itemName, ID = itemData.Id, Amount = itemData.Amount, Type = itemType }
                else
                    aggregated[itemData.Id].Amount = aggregated[itemData.Id].Amount + itemData.Amount
                end
            end
        end
        local inventoryList = {}
        for _, data in pairs(aggregated) do table.insert(inventoryList, data) end
        table.sort(inventoryList, function(a, b) return (a.Name or ""):lower() < (b.Name or ""):lower() end)
        return inventoryList
    end

    local function GetInventorySlot(targetName)
        if not targetName or targetName == "" then return nil end
        for slot, data in pairs(Inventory.Stacks or {}) do
            if data and data.Id and (data.Amount or 0) > 0 then
                local name = tostring(ItemsManager.GetName(data.Id) or "")
                if name:lower() == targetName:lower() then return slot end
            end
        end
        return nil
    end

    local function GetInventoryAmount(targetName)
        if not targetName or targetName == "" then return 0 end
        local total = 0
        for slot, data in pairs(Inventory.Stacks or {}) do
            if data and data.Id and (data.Amount or 0) > 0 then
                local name = tostring(ItemsManager.GetName(data.Id) or "")
                if name:lower() == targetName:lower() then total = total + data.Amount end
            end
        end
        return total
    end

    local function EvaluateIfCondition(taskStr)
        local parts = string.split(tostring(taskStr or ""), ":")
        local targetItem = parts[2] or ""
        local op = parts[3] or "=="
        local targetVal = tonumber(parts[4]) or 0
        local currentCount = GetInventoryAmount(targetItem)
        if op == ">=" then return (currentCount >= targetVal)
        elseif op == "<=" then return (currentCount <= targetVal)
        elseif op == ">" then return (currentCount > targetVal)
        elseif op == "<" then return (currentCount < targetVal)
        elseif op == "==" then return (currentCount == targetVal) end
        return false
    end

    local function ProcessAutoDrop()
        if not STATE.autoDrop then return end
        if _G.CurrentlyProcessingInv then return end 
        
        _G.CurrentlyProcessingInv = true
        task.spawn(function()
            local droppedAnything = false
            for slot, data in pairs(Inventory.Stacks or {}) do
                if data and data.Id and (data.Amount or 0) > 0 then
                    local name = tostring(ItemsManager.GetName(data.Id) or "")
                    local mode = STATE.dropConfig[name] or "IGNORE"
                    
                    if mode == "DROP" then
                        _G.TargetPromptAmount = data.Amount < 200 and data.Amount or 200
                        PlayerDrop:FireServer(slot)
                        task.wait(1.5)
                        droppedAnything = true
                    elseif mode == "TRASH" then
                        _G.TargetPromptAmount = data.Amount
                        PlayerItemTrash:FireServer(slot)
                        task.wait(1.5)
                        droppedAnything = true
                    end
                end
            end
            if not droppedAnything then task.wait(0.5) end
            _G.CurrentlyProcessingInv = false
        end)
    end

    local function RenderFactoryQueueStr()
        local displayStr = ""
        for i, q in ipairs(STATE.factoryQueue or {}) do 
            local shortQ = tostring(q or "")
            if string.sub(shortQ, 1, 6) == "CHECK:" then shortQ = "CHK " .. string.sub(shortQ, 7)
            elseif string.sub(shortQ, 1, 5) == "MOVE:" then shortQ = "GO " .. string.sub(shortQ, 6)
            elseif string.sub(shortQ, 1, 3) == "Y1:" then shortQ = "Y1 " .. string.sub(shortQ, 4)
            elseif string.sub(shortQ, 1, 10) == "LOOP_START" then shortQ = "L_START("..(string.split(shortQ,":")[2] or "0")..")"
            elseif string.sub(shortQ, 1, 5) == "PLACE" then shortQ = "PLC " .. (string.split(shortQ,":")[2] or "")
            elseif string.sub(shortQ, 1, 4) == "FARM" then shortQ = "FRM " .. (string.split(shortQ,":")[2] or "")
            elseif string.sub(shortQ, 1, 5) == "DROP:" then shortQ = "DRP " .. string.sub(shortQ, 6)
            end
            displayStr = displayStr .. (i>1 and "->" or "") .. shortQ 
        end
        return displayStr == "" and "[EMPTY]" or displayStr
    end

    -- ==========================================
    -- UI CONSTRUCTION (MOBILE FRIENDLY)
    -- ==========================================
    UI.Screen = Instance.new("ScreenGui")
    UI.Screen.Name = "TitanEnterpriseUI"
    UI.Screen.ResetOnSpawn = false
    UI.Screen.Parent = pcall(function() return coreGui.Name end) and coreGui or player:WaitForChild("PlayerGui")

    UI.MainFrame = Instance.new("Frame", UI.Screen)
    UI.MainFrame.Size = UDim2.new(0, 450, 0, 320) 
    UI.MainFrame.Position = UDim2.new(0.5, -225, 0.5, -160)
    UI.MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    UI.MainFrame.Active = true; UI.MainFrame.Draggable = true 
    Instance.new("UICorner", UI.MainFrame).CornerRadius = UDim.new(0, 6)
    
    do
        local MainStroke = Instance.new("UIStroke", UI.MainFrame); MainStroke.Color = Color3.fromRGB(40, 40, 50); MainStroke.Thickness = 1
        
        local TitleBar = Instance.new("Frame", UI.MainFrame)
        TitleBar.Size = UDim2.new(1, 0, 0, 30); TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 6)
        local TitleFix = Instance.new("Frame", TitleBar)
        TitleFix.Size = UDim2.new(1, 0, 0, 6); TitleFix.Position = UDim2.new(0, 0, 1, -6)
        TitleFix.BackgroundColor3 = Color3.fromRGB(25, 25, 30); TitleFix.BorderSizePixel = 0

        local TitleTxt = Instance.new("TextLabel", TitleBar)
        TitleTxt.Size = UDim2.new(0.7, 0, 1, 0); TitleTxt.Position = UDim2.new(0, 10, 0, 0)
        TitleTxt.BackgroundTransparency = 1; TitleTxt.Text = "TITAN V983 (SMART FRAME PATH & SOLID Y+1)"
        TitleTxt.TextColor3 = Color3.fromRGB(0, 255, 255); TitleTxt.Font = Enum.Font.GothamBlack; TitleTxt.TextSize = 11
        TitleTxt.TextXAlignment = Enum.TextXAlignment.Left

        UI.BtnMin = Instance.new("TextButton", TitleBar)
        UI.BtnMin.Size = UDim2.new(0, 30, 0, 30); UI.BtnMin.Position = UDim2.new(1, -60, 0, 0)
        UI.BtnMin.BackgroundTransparency = 1; UI.BtnMin.Text = "-"; UI.BtnMin.TextColor3 = Color3.new(1,1,1)
        UI.BtnMin.Font = Enum.Font.GothamBold; UI.BtnMin.TextSize = 16

        UI.BtnClose = Instance.new("TextButton", TitleBar)
        UI.BtnClose.Size = UDim2.new(0, 30, 0, 30); UI.BtnClose.Position = UDim2.new(1, -30, 0, 0)
        UI.BtnClose.BackgroundTransparency = 1; UI.BtnClose.Text = "X"; UI.BtnClose.TextColor3 = Color3.fromRGB(255, 50, 50)
        UI.BtnClose.Font = Enum.Font.GothamBold; UI.BtnClose.TextSize = 14
    end

    UI.TabContainer = Instance.new("Frame", UI.MainFrame)
    UI.TabContainer.Size = UDim2.new(0, 90, 1, -30); UI.TabContainer.Position = UDim2.new(0, 0, 0, 30)
    UI.TabContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25); UI.TabContainer.BorderSizePixel = 0
    Instance.new("UIListLayout", UI.TabContainer)

    local function CreateTab(name)
        local btn = Instance.new("TextButton", UI.TabContainer)
        btn.Size = UDim2.new(1, 0, 0, 35); btn.BackgroundTransparency = 1
        btn.Text = name; btn.TextColor3 = Color3.new(0.5, 0.5, 0.5)
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 9
        return btn
    end

    UI.TabHomeBtn = CreateTab("HOME")
    UI.TabRadarBtn = CreateTab("RADAR")
    UI.TabBotBtn = CreateTab("BOT MENU")
    UI.TabFactoryBtn = CreateTab("PABRIK")
    UI.TabInvBtn = CreateTab("INV")
    UI.TabSettingsBtn = CreateTab("SETTINGS")

    UI.PageContainer = Instance.new("Frame", UI.MainFrame)
    UI.PageContainer.Size = UDim2.new(1, -90, 1, -50); UI.PageContainer.Position = UDim2.new(0, 90, 0, 30)
    UI.PageContainer.BackgroundTransparency = 1

    UI.GlobalStatus = Instance.new("TextLabel", UI.MainFrame)
    UI.GlobalStatus.Size = UDim2.new(1, -90, 0, 20); UI.GlobalStatus.Position = UDim2.new(0, 90, 1, -20)
    UI.GlobalStatus.BackgroundColor3 = Color3.fromRGB(10, 10, 15); UI.GlobalStatus.Text = " STATUS: INITIALIZING"
    UI.GlobalStatus.TextColor3 = Color3.fromRGB(0, 255, 0); UI.GlobalStatus.Font = Enum.Font.GothamBold; UI.GlobalStatus.TextSize = 9
    UI.GlobalStatus.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", UI.GlobalStatus).CornerRadius = UDim.new(0, 4)

    local function MakeScroll(parent, canvasHeight)
        local sf = Instance.new("ScrollingFrame", parent)
        sf.Size = UDim2.new(1, 0, 1, 0); sf.BackgroundTransparency = 1; sf.ScrollBarThickness = 3
        sf.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
        return sf
    end

    UI.PageHome = MakeScroll(UI.PageContainer, 600)
    UI.PageRadar = Instance.new("Frame", UI.PageContainer); UI.PageRadar.Size = UDim2.new(1, -6, 1, -6); UI.PageRadar.Position = UDim2.new(0, 3, 0, 3); UI.PageRadar.BackgroundTransparency = 1; UI.PageRadar.Visible = false
    UI.PageBot = MakeScroll(UI.PageContainer, 500); UI.PageBot.Visible = false 
    UI.PageFactory = MakeScroll(UI.PageContainer, 550); UI.PageFactory.Visible = false
    UI.PageInv = Instance.new("Frame", UI.PageContainer); UI.PageInv.Size = UDim2.new(1, -6, 1, -6); UI.PageInv.Position = UDim2.new(0, 3, 0, 3); UI.PageInv.BackgroundTransparency = 1; UI.PageInv.Visible = false
    UI.PageSettings = Instance.new("Frame", UI.PageContainer); UI.PageSettings.Size = UDim2.new(1, -6, 1, -6); UI.PageSettings.Position = UDim2.new(0, 3, 0, 3); UI.PageSettings.BackgroundTransparency = 1; UI.PageSettings.Visible = false

    -- ==========================================
    -- NEW TAB: 5x5 EXACT RADAR
    -- ==========================================
    do
        local RadarTitle = Instance.new("TextLabel", UI.PageRadar)
        RadarTitle.Size = UDim2.new(1, 0, 0, 20); RadarTitle.Position = UDim2.new(0, 0, 0, 5)
        RadarTitle.BackgroundTransparency = 1; RadarTitle.Text = "📡 EXACT 5x5 RADAR (AUTO SCAN)"
        RadarTitle.TextColor3 = Color3.fromRGB(0, 255, 255); RadarTitle.Font = Enum.Font.GothamBlack; RadarTitle.TextSize = 12

        local RadarInfo = Instance.new("TextLabel", UI.PageRadar)
        RadarInfo.Size = UDim2.new(1, 0, 0, 15); RadarInfo.Position = UDim2.new(0, 0, 0, 25)
        RadarInfo.BackgroundTransparency = 1; RadarInfo.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        RadarInfo.Text = "Real-time rendering aktif. C = Center."
        RadarInfo.Font = Enum.Font.GothamBold; RadarInfo.TextSize = 9

        local RadarGridFrame = Instance.new("Frame", UI.PageRadar)
        RadarGridFrame.Size = UDim2.new(0, 250, 0, 150)
        RadarGridFrame.Position = UDim2.new(0.5, -125, 0, 45)
        RadarGridFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        Instance.new("UICorner", RadarGridFrame).CornerRadius = UDim.new(0, 4)
        local RadarStroke = Instance.new("UIStroke", RadarGridFrame); RadarStroke.Color = Color3.fromRGB(40, 40, 50); RadarStroke.Thickness = 1
        
        local UIGrid = Instance.new("UIGridLayout", RadarGridFrame)
        UIGrid.CellSize = UDim2.new(0, 48, 0, 28)
        UIGrid.CellPadding = UDim2.new(0, 2, 0, 2)
        UIGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIGrid.VerticalAlignment = Enum.VerticalAlignment.Center
        
        UI.RadarSlots = {}
        for i = 1, 25 do
            local b = Instance.new("Frame", RadarGridFrame)
            b.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 2)
            local l = Instance.new("TextLabel", b)
            l.Size = UDim2.new(1, -2, 1, -2); l.Position = UDim2.new(0, 1, 0, 1)
            l.BackgroundTransparency = 1
            l.Font = Enum.Font.Code; l.TextColor3 = Color3.new(1, 1, 1)
            l.TextScaled = true; local constraint = Instance.new("UITextSizeConstraint", l); constraint.MinTextSize = 4; constraint.MaxTextSize = 8
            UI.RadarSlots[i] = {Frame = b, Label = l}
        end
    end

    -- ==========================================
    -- HOME CONTENT
    -- ==========================================
    do
        local LblName = Instance.new("TextLabel", UI.PageHome)
        LblName.Size = UDim2.new(1, -10, 0, 15); LblName.Position = UDim2.new(0, 10, 0, 5)
        LblName.BackgroundTransparency = 1; LblName.Text = "PLAYER: " .. string.upper(player.Name or "UNKNOWN")
        LblName.TextColor3 = Color3.new(1,1,1); LblName.Font = Enum.Font.GothamBlack; LblName.TextSize = 10
        LblName.TextXAlignment = Enum.TextXAlignment.Left

        local LblWorld = Instance.new("TextLabel", UI.PageHome)
        LblWorld.Size = UDim2.new(1, -10, 0, 15); LblWorld.Position = UDim2.new(0, 10, 0, 20)
        LblWorld.BackgroundTransparency = 1; LblWorld.Text = "WORLD ID: " .. tostring(game.PlaceId or "0")
        LblWorld.TextColor3 = Color3.new(0.8,0.8,0.8); LblWorld.Font = Enum.Font.GothamBold; LblWorld.TextSize = 9
        LblWorld.TextXAlignment = Enum.TextXAlignment.Left

        UI.LblLoc = Instance.new("TextLabel", UI.PageHome)
        UI.LblLoc.Size = UDim2.new(1, -10, 0, 15); UI.LblLoc.Position = UDim2.new(0, 10, 0, 35)
        UI.LblLoc.BackgroundTransparency = 1; UI.LblLoc.Text = "LOCATION: X: 0 | Y: 0"
        UI.LblLoc.TextColor3 = Color3.fromRGB(0, 255, 255); UI.LblLoc.Font = Enum.Font.GothamBold; UI.LblLoc.TextSize = 9
        UI.LblLoc.TextXAlignment = Enum.TextXAlignment.Left

        local AnalyticsContainer = Instance.new("Frame", UI.PageHome)
        AnalyticsContainer.Size = UDim2.new(1, -15, 0, 400); AnalyticsContainer.Position = UDim2.new(0, 8, 0, 55)
        AnalyticsContainer.BackgroundTransparency = 1
        
        local CardGrid = Instance.new("UIGridLayout", AnalyticsContainer)
        CardGrid.CellSize = UDim2.new(0.48, 0, 0, 120)
        CardGrid.CellPadding = UDim2.new(0.04, 0, 0, 8)
        CardGrid.SortOrder = Enum.SortOrder.LayoutOrder

        UI.AnalyticsCards = {}

        local function CreateCard(name, order)
            local card = Instance.new("Frame", AnalyticsContainer)
            card.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            card.LayoutOrder = order
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 4)
            local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(40, 40, 50); stroke.Thickness = 1
            
            local title = Instance.new("TextLabel", card)
            title.Size = UDim2.new(1, -6, 0, 15); title.Position = UDim2.new(0, 3, 0, 2)
            title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(0, 200, 255)
            title.Font = Enum.Font.GothamBold; title.TextSize = 9; title.Text = name
            title.TextXAlignment = Enum.TextXAlignment.Center

            local div = Instance.new("Frame", card)
            div.Size = UDim2.new(1, -6, 0, 1); div.Position = UDim2.new(0, 3, 0, 17)
            div.BackgroundColor3 = Color3.fromRGB(40, 40, 50); div.BorderSizePixel = 0

            local scroll = Instance.new("ScrollingFrame", card)
            scroll.Size = UDim2.new(1, -4, 1, -20); scroll.Position = UDim2.new(0, 2, 0, 19)
            scroll.BackgroundTransparency = 1; scroll.ScrollBarThickness = 2
            
            local txt = Instance.new("TextLabel", scroll)
            txt.Size = UDim2.new(1, -4, 1, 0); txt.Position = UDim2.new(0, 2, 0, 2)
            txt.BackgroundTransparency = 1; txt.TextColor3 = Color3.new(0.9, 0.9, 0.9)
            txt.Font = Enum.Font.Code; txt.TextSize = 8
            txt.TextXAlignment = Enum.TextXAlignment.Left; txt.TextYAlignment = Enum.TextYAlignment.Top
            txt.TextWrapped = true

            UI.AnalyticsCards[name] = {Scroll = scroll, Text = txt}
        end

        CreateCard("🌍 WORLD STATS", 1)
        CreateCard("📦 DROPS", 2)
        CreateCard("🔒 PROTECTED", 3)
        CreateCard("🟫 BLOCKS & BG", 4)
        CreateCard("🌱 PLANTS", 5)
        CreateCard("⚠️ HAZARDS", 6)
    end

    -- ==========================================
    -- CLEAN UI COMPONENT HELPERS
    -- ==========================================
    local function CreateHRow(parent, height)
        local row = Instance.new("Frame", parent)
        row.Size = UDim2.new(1, 0, 0, height); row.BackgroundTransparency = 1
        local layout = Instance.new("UIListLayout", row)
        layout.FillDirection = Enum.FillDirection.Horizontal; layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 4)
        return row
    end

    local function CreateSection(parent, title, height, order)
        local sec = Instance.new("Frame", parent)
        sec.Size = UDim2.new(1, 0, 0, height); sec.BackgroundColor3 = Color3.fromRGB(25, 25, 30); sec.LayoutOrder = order
        Instance.new("UICorner", sec).CornerRadius = UDim.new(0, 4)
        local secPadding = Instance.new("UIPadding", sec)
        secPadding.PaddingTop = UDim.new(0, 4); secPadding.PaddingLeft = UDim.new(0, 6); secPadding.PaddingRight = UDim.new(0, 6)
        local secList = Instance.new("UIListLayout", sec); secList.Padding = UDim.new(0, 4); secList.SortOrder = Enum.SortOrder.LayoutOrder
        local t = Instance.new("TextLabel", sec)
        t.Size = UDim2.new(1, 0, 0, 12); t.BackgroundTransparency = 1; t.Text = title; t.TextColor3 = Color3.fromRGB(255, 150, 0)
        t.Font = Enum.Font.GothamBlack; t.TextSize = 9; t.TextXAlignment = Enum.TextXAlignment.Left
        return sec
    end

    local function CreateUIObj(type, parent, scaleWidth, placeholderOrText, color)
        local obj = Instance.new(type, parent)
        obj.Size = UDim2.new(scaleWidth, -4, 1, 0) 
        obj.BackgroundColor3 = color or Color3.fromRGB(15, 15, 20)
        obj.TextColor3 = Color3.new(1,1,1); obj.Font = Enum.Font.GothamBold; obj.TextSize = 9
        if type == "TextBox" then obj.PlaceholderText = placeholderOrText; obj.Text = "" else obj.Text = placeholderOrText end
        Instance.new("UICorner", obj).CornerRadius = UDim.new(0, 3)
        return obj
    end

    local BotLayout = Instance.new("UIListLayout", UI.PageBot); BotLayout.Padding = UDim.new(0, 6); BotLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local BotPadding = Instance.new("UIPadding", UI.PageBot); BotPadding.PaddingTop = UDim.new(0, 6); BotPadding.PaddingLeft = UDim.new(0, 6); BotPadding.PaddingRight = UDim.new(0, 6)
    local FactoryLayout = Instance.new("UIListLayout", UI.PageFactory); FactoryLayout.Padding = UDim.new(0, 5); FactoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local FactoryPadding = Instance.new("UIPadding", UI.PageFactory); FactoryPadding.PaddingTop = UDim.new(0, 6); FactoryPadding.PaddingLeft = UDim.new(0, 6); FactoryPadding.PaddingRight = UDim.new(0, 6)

    -- ==========================================
    -- BOT MENU CONSTRUCTION (PageBot)
    -- ==========================================
    do
        local SecClear = CreateSection(UI.PageBot, "BOT AUTO CLEAR", 75, 1)
        local RowClear1 = CreateHRow(SecClear, 20)
        UI.InpClearX1 = CreateUIObj("TextBox", RowClear1, 0.25, "Min X"); UI.InpClearX2 = CreateUIObj("TextBox", RowClear1, 0.25, "Max X")
        UI.InpClearY1 = CreateUIObj("TextBox", RowClear1, 0.25, "Max Y"); UI.InpClearY2 = CreateUIObj("TextBox", RowClear1, 0.25, "Min Y")
        local RowClear2 = CreateHRow(SecClear, 20); UI.BtnClear = CreateUIObj("TextButton", RowClear2, 1.0, "CLEAR: OFF", Color3.fromRGB(120, 0, 0))

        local SecFarm = CreateSection(UI.PageBot, "BOT AUTO FARM", 100, 2)
        local RowFarm1 = CreateHRow(SecFarm, 20); UI.InpFarmY1 = CreateUIObj("TextBox", RowFarm1, 0.5, "Start Y"); UI.InpFarmY2 = CreateUIObj("TextBox", RowFarm1, 0.5, "End Y")
        local RowFarm2 = CreateHRow(SecFarm, 20); UI.BtnFarmBlock = CreateUIObj("TextButton", RowFarm2, 0.6, "SELECT SAPLING", Color3.fromRGB(0, 100, 150)); UI.BtnFarm = CreateUIObj("TextButton", RowFarm2, 0.4, "FARM: OFF", Color3.fromRGB(120, 0, 0))
        local RowFarm3 = CreateHRow(SecFarm, 20); UI.InpFarmTimer = CreateUIObj("TextBox", RowFarm3, 1.0, "Input Grow Timer (Detik)"); UI.InpFarmTimer.Text = "30"

        local SecPlace = CreateSection(UI.PageBot, "BOT AUTO PLACE", 45, 3)
        local RowPlace = CreateHRow(SecPlace, 20); UI.BtnPlaceBlock = CreateUIObj("TextButton", RowPlace, 0.6, "SELECT BLOCK", Color3.fromRGB(0, 100, 150)); UI.BtnPlace = CreateUIObj("TextButton", RowPlace, 0.4, "PLACE: OFF", Color3.fromRGB(120, 0, 0))

        local SecY1 = CreateSection(UI.PageBot, "BOT AUTO Y+1", 100, 4)
        local RowY1_1 = CreateHRow(SecY1, 20); UI.InpY1X = CreateUIObj("TextBox", RowY1_1, 0.5, "Lock X"); UI.InpY1Y = CreateUIObj("TextBox", RowY1_1, 0.5, "Lock Y")
        local RowY1_2 = CreateHRow(SecY1, 20); UI.BtnY1Block = CreateUIObj("TextButton", RowY1_2, 0.6, "SELECT BLOCK", Color3.fromRGB(0, 100, 150)); UI.BtnY1 = CreateUIObj("TextButton", RowY1_2, 0.4, "Y+1: OFF", Color3.fromRGB(120, 0, 0))
        local RowY1_3 = CreateHRow(SecY1, 20); UI.BtnSaplingSensor = CreateUIObj("TextButton", RowY1_3, 1.0, "SENSOR SAPLING ONLY: OFF", Color3.fromRGB(120, 0, 0))

        local SecDrop = CreateSection(UI.PageBot, "BOT AUTO DROP", 75, 5)
        local RowDrop1 = CreateHRow(SecDrop, 20); UI.InpDropX = CreateUIObj("TextBox", RowDrop1, 0.5, "Target X"); UI.InpDropY = CreateUIObj("TextBox", RowDrop1, 0.5, "Target Y")
        local RowDrop2 = CreateHRow(SecDrop, 20); UI.BtnDropConfig = CreateUIObj("TextButton", RowDrop2, 0.6, "SET GLOBAL DROP LIST", Color3.fromRGB(0, 100, 150)); UI.UI_BtnDrop = CreateUIObj("TextButton", RowDrop2, 0.4, "DROP: OFF", Color3.fromRGB(120, 0, 0))

        local SecLoot = CreateSection(UI.PageBot, "BOT AUTO LOOT", 45, 6)
        local RowLoot = CreateHRow(SecLoot, 20); UI.BtnLoot = CreateUIObj("TextButton", RowLoot, 1.0, "LOOT: OFF", Color3.fromRGB(120, 0, 0))
    end

    -- ==========================================
    -- FACTORY CONTENT (PageFactory)
    -- ==========================================
    do
        UI.FactoryQueueVisual = Instance.new("TextLabel", UI.PageFactory)
        UI.FactoryQueueVisual.Size = UDim2.new(1, 0, 0, 40); UI.FactoryQueueVisual.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        UI.FactoryQueueVisual.Text = "QUEUE: [EMPTY]"; UI.FactoryQueueVisual.TextColor3 = Color3.new(1,1,1); UI.FactoryQueueVisual.Font = Enum.Font.Code; UI.FactoryQueueVisual.TextSize = 9
        UI.FactoryQueueVisual.TextWrapped = true; UI.FactoryQueueVisual.LayoutOrder = 1; Instance.new("UICorner", UI.FactoryQueueVisual).CornerRadius = UDim.new(0, 4)

        local FRow1 = CreateHRow(UI.PageFactory, 25); FRow1.LayoutOrder = 2
        UI.BtnFactClear = CreateUIObj("TextButton", FRow1, 0.33, "+ CLEAR", Color3.fromRGB(40, 40, 50)); UI.BtnFactLoot  = CreateUIObj("TextButton", FRow1, 0.33, "+ LOOT", Color3.fromRGB(40, 40, 50)); UI.BtnFactStop  = CreateUIObj("TextButton", FRow1, 0.34, "+ STOP", Color3.fromRGB(150, 40, 40))

        local FRow2 = CreateHRow(UI.PageFactory, 25); FRow2.LayoutOrder = 3
        UI.BtnFactY1    = CreateUIObj("TextButton", FRow2, 0.5, "+ Y+1", Color3.fromRGB(0, 100, 150)); UI.BtnFactPlace = CreateUIObj("TextButton", FRow2, 0.5, "+ PLACE", Color3.fromRGB(0, 120, 80))

        local FRow3 = CreateHRow(UI.PageFactory, 25); FRow3.LayoutOrder = 4
        UI.InpFactMoveX = CreateUIObj("TextBox", FRow3, 0.25, "Tgt X"); UI.InpFactMoveY = CreateUIObj("TextBox", FRow3, 0.25, "Tgt Y"); UI.BtnFactMove  = CreateUIObj("TextButton", FRow3, 0.5, "+ MOVE", Color3.fromRGB(150, 50, 150))

        local FRow4 = CreateHRow(UI.PageFactory, 25); FRow4.LayoutOrder = 5
        UI.InpFactFarmY1 = CreateUIObj("TextBox", FRow4, 0.15, "Y1"); UI.InpFactFarmY2 = CreateUIObj("TextBox", FRow4, 0.15, "Y2"); 
        UI.InpFactFarmTimer = CreateUIObj("TextBox", FRow4, 0.2, "Time(s)"); UI.InpFactFarmTimer.Text = "30"
        UI.BtnFactFarm   = CreateUIObj("TextButton", FRow4, 0.5, "+ FARM", Color3.fromRGB(0, 150, 0))

        local FRow5 = CreateHRow(UI.PageFactory, 25); FRow5.LayoutOrder = 6
        UI.BtnFactDropSel = CreateUIObj("TextButton", FRow5, 1.0, "+ DYNAMIC DROP", Color3.fromRGB(180, 100, 0))

        local FRow6 = CreateHRow(UI.PageFactory, 25); FRow6.LayoutOrder = 7
        UI.BtnFactChkItem = CreateUIObj("TextButton", FRow6, 0.35, "SEL ITEM", Color3.fromRGB(0, 100, 150)); UI.BtnFactChkOp    = CreateUIObj("TextButton", FRow6, 0.15, ">=", Color3.fromRGB(30, 30, 35)); UI.BtnFactChkOp.TextColor3 = Color3.new(1,1,0)
        UI.InpFactChkAmt  = CreateUIObj("TextBox", FRow6, 0.2, "Amt"); UI.BtnFactChkAdd  = CreateUIObj("TextButton", FRow6, 0.3, "+ CHK", Color3.fromRGB(150, 100, 0))

        local FRow7 = CreateHRow(UI.PageFactory, 25); FRow7.LayoutOrder = 8
        UI.InpFactLoopLim = CreateUIObj("TextBox", FRow7, 0.3, "Lim(0=Inf)"); UI.BtnFactLoopStart = CreateUIObj("TextButton", FRow7, 0.35, "[ L_START ]", Color3.fromRGB(50, 50, 60)); UI.BtnFactLoopEnd   = CreateUIObj("TextButton", FRow7, 0.35, "[ L_END ]", Color3.fromRGB(50, 50, 60))

        local FRow8 = CreateHRow(UI.PageFactory, 30); FRow8.LayoutOrder = 9
        UI.BtnClearQueue = CreateUIObj("TextButton", FRow8, 0.5, "RESET QUEUE", Color3.fromRGB(150, 50, 0)); UI.BtnStartFactory = CreateUIObj("TextButton", FRow8, 0.5, "▶ START PABRIK", Color3.fromRGB(0, 100, 200)); UI.BtnStartFactory.Font = Enum.Font.GothamBlack

        local GuideBox = Instance.new("TextLabel", UI.PageFactory)
        GuideBox.Size = UDim2.new(1, 0, 0, 120); GuideBox.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        GuideBox.Text = "📖 PANDUAN PABRIK\n1. COMBO WAJIB: '+ MOVE' sebelum Y+1, Drop, Farm.\n2. CHECK: Robot DIAM MENUNGGU item.\n3. FARM: Isi Y1, Y2 & Timer (Detik) panen."
        GuideBox.TextColor3 = Color3.fromRGB(180, 180, 180); GuideBox.Font = Enum.Font.GothamMedium; GuideBox.TextSize = 8; GuideBox.TextXAlignment = Enum.TextXAlignment.Left; GuideBox.TextYAlignment = Enum.TextYAlignment.Top; GuideBox.TextWrapped = true; GuideBox.LayoutOrder = 10
        Instance.new("UICorner", GuideBox).CornerRadius = UDim.new(0, 4)
        local GuidePad = Instance.new("UIPadding", GuideBox); GuidePad.PaddingTop = UDim.new(0, 6); GuidePad.PaddingLeft = UDim.new(0, 6); GuidePad.PaddingRight = UDim.new(0, 6)
    end

    -- ==========================================
    -- INVENTORY PAGE (PageInv)
    -- ==========================================
    do
        UI.SearchBar = Instance.new("TextBox", UI.PageInv)
        UI.SearchBar.Size = UDim2.new(1, 0, 0, 25); UI.SearchBar.Position = UDim2.new(0, 0, 0, 0); UI.SearchBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30); UI.SearchBar.TextColor3 = Color3.new(1,1,1); UI.SearchBar.PlaceholderText = "Live Search Item..."; UI.SearchBar.Text = ""; UI.SearchBar.Font = Enum.Font.GothamBold; UI.SearchBar.TextSize = 10; Instance.new("UICorner", UI.SearchBar).CornerRadius = UDim.new(0, 3)
        UI.SelectWarn = Instance.new("TextLabel", UI.PageInv)
        UI.SelectWarn.Size = UDim2.new(1, 0, 0, 20); UI.SelectWarn.Position = UDim2.new(0, 0, 0, 25); UI.SelectWarn.BackgroundTransparency = 1; UI.SelectWarn.TextColor3 = Color3.fromRGB(255, 255, 0); UI.SelectWarn.Font = Enum.Font.GothamBold; UI.SelectWarn.TextSize = 9; UI.SelectWarn.Visible = false
        UI.InvScroll = Instance.new("ScrollingFrame", UI.PageInv)
        UI.InvScroll.Size = UDim2.new(1, 0, 1, -50); UI.InvScroll.Position = UDim2.new(0, 0, 0, 50); UI.InvScroll.BackgroundTransparency = 1; UI.InvScroll.ScrollBarThickness = 3; local InvListLayout = Instance.new("UIListLayout", UI.InvScroll); InvListLayout.Padding = UDim.new(0, 3)
    end

    -- ==========================================
    -- SETTINGS TAB (PageSettings)
    -- ==========================================
    do
        local SettingsTitle = Instance.new("TextLabel", UI.PageSettings)
        SettingsTitle.Size = UDim2.new(1, 0, 0, 20); SettingsTitle.BackgroundTransparency = 1; SettingsTitle.Text = "CONFIGURATION MANAGER"; SettingsTitle.TextColor3 = Color3.fromRGB(0, 255, 255); SettingsTitle.Font = Enum.Font.GothamBlack; SettingsTitle.TextSize = 12
        UI.BtnSaveConfig = Instance.new("TextButton", UI.PageSettings)
        UI.BtnSaveConfig.Size = UDim2.new(1, 0, 0, 30); UI.BtnSaveConfig.Position = UDim2.new(0, 0, 0, 30); UI.BtnSaveConfig.BackgroundColor3 = Color3.fromRGB(0, 150, 100); UI.BtnSaveConfig.Text = "💾 SAVE CONFIGURATION"; UI.BtnSaveConfig.TextColor3 = Color3.new(1,1,1); UI.BtnSaveConfig.Font = Enum.Font.GothamBold; UI.BtnSaveConfig.TextSize = 10; Instance.new("UICorner", UI.BtnSaveConfig).CornerRadius = UDim.new(0, 4)
        UI.BtnLoadConfig = Instance.new("TextButton", UI.PageSettings)
        UI.BtnLoadConfig.Size = UDim2.new(1, 0, 0, 30); UI.BtnLoadConfig.Position = UDim2.new(0, 0, 0, 65); UI.BtnLoadConfig.BackgroundColor3 = Color3.fromRGB(150, 100, 0); UI.BtnLoadConfig.Text = "📂 LOAD CONFIGURATION"; UI.BtnLoadConfig.TextColor3 = Color3.new(1,1,1); UI.BtnLoadConfig.Font = Enum.Font.GothamBold; UI.BtnLoadConfig.TextSize = 10; Instance.new("UICorner", UI.BtnLoadConfig).CornerRadius = UDim.new(0, 4)
        UI.ConfigStatus = Instance.new("TextLabel", UI.PageSettings)
        UI.ConfigStatus.Size = UDim2.new(1, 0, 0, 20); UI.ConfigStatus.Position = UDim2.new(0, 0, 0, 100); UI.ConfigStatus.BackgroundTransparency = 1; UI.ConfigStatus.Text = "No Config Loaded."; UI.ConfigStatus.TextColor3 = Color3.fromRGB(150, 150, 150); UI.ConfigStatus.Font = Enum.Font.GothamMedium; UI.ConfigStatus.TextSize = 9
    end

    local ConfigDataName = "TitanEnterpriseConfig.json"

    UI.BtnSaveConfig.MouseButton1Click:Connect(function()
        local dataToSave = {
            farmTargetBlock = STATE.farmTargetBlock, placeTargetBlock = STATE.placeTargetBlock, 
            farmStartY = tonumber(UI.InpFarmY1.Text) or 60, farmEndY = tonumber(UI.InpFarmY2.Text) or 6,
            farmTimer = tonumber(UI.InpFarmTimer.Text) or 30, 
            clearStartX = tonumber(UI.InpClearX1.Text) or 0, clearEndX = tonumber(UI.InpClearX2.Text) or 100,
            clearStartY = tonumber(UI.InpClearY1.Text) or 60, clearEndY = tonumber(UI.InpClearY2.Text) or 0,
            y1TargetBlock = STATE.y1TargetBlock, lockX = tonumber(UI.InpY1X.Text) or 0, lockY = tonumber(UI.InpY1Y.Text) or 0, 
            dropX = tonumber(UI.InpDropX.Text) or 0, dropY = tonumber(UI.InpDropY.Text) or 0,
            dropConfig = STATE.dropConfig, factoryQueue = STATE.factoryQueue,
            TreeTracker = STATE.TreeTracker
        }
        local success, result = pcall(function() return HttpService:JSONEncode(dataToSave) end)
        if success and writefile then pcall(function() writefile(ConfigDataName, result) end); UI.ConfigStatus.Text = "✔ Configuration Saved Successfully!"; UI.ConfigStatus.TextColor3 = Color3.fromRGB(0, 255, 0)
        else UI.ConfigStatus.Text = "❌ Save Failed (Executor not supported)"; UI.ConfigStatus.TextColor3 = Color3.fromRGB(255, 0, 0) end
    end)

    UI.BtnLoadConfig.MouseButton1Click:Connect(function()
        if readfile then
            local success, result = pcall(function() return readfile(ConfigDataName) end)
            if success and result then
                local decodeSuccess, data = pcall(function() return HttpService:JSONDecode(result) end)
                if decodeSuccess and data then
                    STATE.farmTargetBlock = data.farmTargetBlock or ""; STATE.placeTargetBlock = data.placeTargetBlock or ""; STATE.y1TargetBlock = data.y1TargetBlock or ""
                    STATE.dropConfig = data.dropConfig or {}; STATE.factoryQueue = data.factoryQueue or {}; STATE.TreeTracker = data.TreeTracker or {}
                    STATE.customFarmTimer = tonumber(data.farmTimer) or 30
                    
                    UI.InpFarmY1.Text = tostring(data.farmStartY or 60); UI.InpFarmY2.Text = tostring(data.farmEndY or 6)
                    UI.InpFarmTimer.Text = tostring(STATE.customFarmTimer)
                    
                    UI.InpClearX1.Text = tostring(data.clearStartX or 0); UI.InpClearX2.Text = tostring(data.clearEndX or 100)
                    UI.InpClearY1.Text = tostring(data.clearStartY or 60); UI.InpClearY2.Text = tostring(data.clearEndY or 0)
                    
                    UI.InpY1X.Text = tostring(data.lockX or 0); UI.InpY1Y.Text = tostring(data.lockY or 0)
                    UI.InpDropX.Text = tostring(data.dropX or 0); UI.InpDropY.Text = tostring(data.dropY or 0)
                    
                    UI.BtnFarmBlock.Text = (STATE.farmTargetBlock ~= "") and string.upper(STATE.farmTargetBlock) or "SELECT SAPLING"
                    UI.BtnPlaceBlock.Text = (STATE.placeTargetBlock ~= "") and string.upper(STATE.placeTargetBlock) or "SELECT BLOCK"
                    UI.BtnY1Block.Text = (STATE.y1TargetBlock ~= "") and string.upper(STATE.y1TargetBlock) or "SELECT BLOCK"

                    UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr(); UI.ConfigStatus.Text = "✔ Configuration Loaded Successfully!"; UI.ConfigStatus.TextColor3 = Color3.fromRGB(0, 255, 0)
                else UI.ConfigStatus.Text = "❌ Load Failed (Data Corrupted)"; UI.ConfigStatus.TextColor3 = Color3.fromRGB(255, 0, 0) end
            else UI.ConfigStatus.Text = "❌ File Not Found!"; UI.ConfigStatus.TextColor3 = Color3.fromRGB(255, 0, 0) end
        else UI.ConfigStatus.Text = "❌ Load Failed (Executor not supported)"; UI.ConfigStatus.TextColor3 = Color3.fromRGB(255, 0, 0) end
    end)

    local function SwitchTab(tab)
        UI.TabHomeBtn.TextColor3 = Color3.new(0.5, 0.5, 0.5); UI.TabRadarBtn.TextColor3 = Color3.new(0.5, 0.5, 0.5); UI.TabBotBtn.TextColor3 = Color3.new(0.5, 0.5, 0.5); UI.TabFactoryBtn.TextColor3 = Color3.new(0.5, 0.5, 0.5); UI.TabInvBtn.TextColor3 = Color3.new(0.5, 0.5, 0.5); UI.TabSettingsBtn.TextColor3 = Color3.new(0.5, 0.5, 0.5)
        UI.PageHome.Visible = false; UI.PageRadar.Visible = false; UI.PageBot.Visible = false; UI.PageFactory.Visible = false; UI.PageInv.Visible = false; UI.PageSettings.Visible = false
        if tab == "Home" then UI.TabHomeBtn.TextColor3 = Color3.new(1,1,1); UI.PageHome.Visible = true
        elseif tab == "Radar" then UI.TabRadarBtn.TextColor3 = Color3.new(1,1,1); UI.PageRadar.Visible = true 
        elseif tab == "Bot" then UI.TabBotBtn.TextColor3 = Color3.new(1,1,1); UI.PageBot.Visible = true 
        elseif tab == "Factory" then UI.TabFactoryBtn.TextColor3 = Color3.new(1,1,1); UI.PageFactory.Visible = true 
        elseif tab == "Inv" then UI.TabInvBtn.TextColor3 = Color3.new(1,1,1); UI.PageInv.Visible = true 
        elseif tab == "Settings" then UI.TabSettingsBtn.TextColor3 = Color3.new(1,1,1); UI.PageSettings.Visible = true end
    end

    -- ==========================================
    -- ENGINE LOGIC
    -- ==========================================

    local function IsProtected(x, y)
        local t = WorldManager.GetTile(x, y, 1) or WorldManager.GetTile(x, y, 2)
        if not t then return false end
        local n = GetSafeName(t)
        return string.find(n, "BEDROCK") or string.find(n, "LOCK") or string.find(n, "SIGN")
    end

    local function IsHazard(x, y)
        local t = WorldManager.GetTile(x, y, 1)
        if not t then return false end
        local n = GetSafeName(t)
        return string.find(n, "MAGMA")
    end

    -- FIX V983: Mencegah Pathfinding Layer 1 Frame hancur jika bergerak ke atas (Lompat)
    local function NeedsBreaking(x, y, ignoreBackground, currentY)
        if IsProtected(x, y) or IsHazard(x, y) then return false end
        local t = WorldManager.GetTile(x, y, 1); local bg = WorldManager.GetTile(x, y, 2)
        local nT = GetSafeName(t); local nBg = GetSafeName(bg)
        if string.find(nT, "DOOR") or string.find(nT, "SIGN") then return false end
        
        -- FIX V983: Frame/Platform bisa ditembus ke atas tanpa perlu dihancurkan
        if currentY and y > currentY and (string.find(nT, "FRAME") or string.find(nT, "PLATFORM") or string.find(nT, "SCAFFOLD") or string.find(nT, "PLAT")) then
            return false
        end

        if nT ~= "AIR" then return true end
        if not ignoreBackground and nBg ~= "AIR" then return true end
        return false
    end

    -- FIX V983: WalkableAir diperbarui agar paham Frame (Bisa dilewati ke atas)
    local function IsWalkableAir(x, y, currentY)
        local t = WorldManager.GetTile(x, y, 1)
        local name = GetSafeName(t)
        if name == "AIR" then return true end
        if string.find(name, "DOOR") or string.find(name, "SIGN") then return true end
        
        if currentY and y > currentY and (string.find(name, "FRAME") or string.find(name, "PLATFORM") or string.find(name, "SCAFFOLD") or string.find(name, "PLAT")) then
            return true 
        end
        return false 
    end

    local function CanPlantAt(x, y)
        local t = WorldManager.GetTile(x, y, 1)
        local n = GetSafeName(t)
        
        if n ~= "AIR" then return false end
        if IsProtected(x, y) then return false end
        
        local groundBelow = WorldManager.GetTile(x, y-1, 1)
        local gn = GetSafeName(groundBelow)
        
        if gn == "AIR" or gn:find("LOCK") or gn:find("DOOR") or gn:find("SIGN") or gn:find("PORTAL") or gn:find("TREE") or gn:find("SAPLING") or gn:find("SEED") then
            return false
        end
        
        if x >= 0 and x <= 99 then
            return true
        end
        return false
    end

    -- FIX V983: GetTileCost menggunakan Matrix Directional untuk mengenali Layer 1 FRAME
    local function GetTileCost(cx, cy, nx, ny, mode)
        if IsHazard(nx, ny) then return math.huge end
        if IsProtected(nx, ny) then return math.huge end 
        local t = WorldManager.GetTile(nx, ny, 1)
        local name = GetSafeName(t)
        
        if name == "AIR" then return 1 end
        if string.find(name, "DOOR") or string.find(name, "SIGN") then return 1 end 
        
        -- FIX V983: ONE-WAY PLATFORM LOGIC
        if string.find(name, "FRAME") or string.find(name, "PLATFORM") or string.find(name, "SCAFFOLD") or string.find(name, "PLAT") then
            if ny > cy then return 1 end -- Gratis kalau gerak ke atas (Lompat nembus)
            -- Ke bawah / horizontal butuh dihancurkan (Solid)
            if mode == "AIR_ONLY" then return math.huge end
            if mode == "LOOT" then return 25 end
            return 15
        end
        
        if mode == "AIR_ONLY" then return math.huge end
        if mode == "LOOT" then return 25 end
        return 15 
    end

    local function FindSmartPath(startX, startY, targetX, targetY, mode)
        local openSet, closedSet = {}, {}
        local startNode = { x = startX, y = startY, g = 0, h = math.abs(startX - targetX) + math.abs(startY - targetY), parent = nil }
        startNode.f = startNode.g + startNode.h
        table.insert(openSet, startNode)

        local iterations = 0
        while #openSet > 0 and iterations < 10000 do
            iterations = iterations + 1
            local currentIndex = 1
            for i = 2, #openSet do if openSet[i].f < openSet[currentIndex].f then currentIndex = i end end
            local current = openSet[currentIndex]
            table.remove(openSet, currentIndex)
            closedSet[current.x .. "_" .. current.y] = true
            
            if current.x == targetX and current.y == targetY then
                local path = {}
                while current.parent do table.insert(path, 1, {x = current.x, y = current.y}); current = current.parent end
                return path
            end
            
            local neighbors = { {x=current.x+1, y=current.y}, {x=current.x-1, y=current.y}, {x=current.x, y=current.y+1}, {x=current.x, y=current.y-1} }
            for _, n in ipairs(neighbors) do
                -- FIX V983: Memberikan cx, cy ke GetTileCost agar pathfinder paham arah (Directional)
                local cost = GetTileCost(current.x, current.y, n.x, n.y, mode) 
                if n.x == targetX and n.y == targetY then cost = 1 end 
                if cost < math.huge and not closedSet[n.x .. "_" .. n.y] then
                    local tentative_g = current.g + cost
                    local inOpen = false
                    for _, openNode in ipairs(openSet) do
                        if openNode.x == n.x and openNode.y == n.y then
                            inOpen = true
                            if tentative_g < openNode.g then openNode.g = tentative_g; openNode.f = openNode.g + openNode.h; openNode.parent = current end
                            break
                        end
                    end
                    if not inOpen then
                        local h = math.abs(n.x - targetX) + math.abs(n.y - targetY)
                        table.insert(openSet, {x = n.x, y = n.y, g = tentative_g, h = h, f = tentative_g + h, parent = current})
                    end
                end
            end
        end
        return nil 
    end

    local function GetHighestBlockTarget(cx, cy)
        local bestTx, bestTy = nil, nil
        local bestScore = math.huge 
        
        local sY = STATE.autoClear and STATE.clearStartY or 60
        local eY = STATE.autoClear and STATE.clearEndY or 0
        local sX = STATE.autoClear and STATE.clearStartX or 0
        local eX = STATE.autoClear and STATE.clearEndX or 100

        for y = sY, eY, -1 do 
            local layerHasBlock = false
            for x = sX, eX do 
                if NeedsBreaking(x, y) then
                    local bKey = x..","..y
                    if not (_G.BlacklistedNodes[bKey] and os.clock() < _G.BlacklistedNodes[bKey]) then
                        layerHasBlock = true
                        local distX = math.abs(cx - x); local distY = math.abs(cy - y)
                        local depthPenalty = (60 - y) * 5
                        local score = distX + (distY * 2) + depthPenalty
                        if score < bestScore then bestScore = score; bestTx = x; bestTy = y end
                    end
                end
            end
            if layerHasBlock and bestScore < 30 then return bestTx, bestTy end
        end
        return bestTx, bestTy
    end

    -- ==========================================
    -- RADAR ENGINE LOGIC (AUTO REAL-TIME)
    -- ==========================================
    local function UpdateRadarUI(cx, cy)
        local index = 1
        for dy = 2, -2, -1 do 
            for dx = -2, 2 do
                local tx = cx + dx
                local ty = cy + dy
                local t1 = WorldManager.GetTile(tx, ty, 1)
                local t2 = WorldManager.GetTile(tx, ty, 2)
                
                local name1 = GetSafeName(t1)
                local name2 = GetSafeName(t2)
                
                local cellData = UI.RadarSlots[index]
                if cellData then
                    local cellTxt = cellData.Label
                    local cellFrame = cellData.Frame

                    if dx == 0 and dy == 0 then
                        cellFrame.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
                        cellTxt.Text = string.format("C [%d,%d]\n%s\n%s", tx, ty, name1, name2)
                        cellTxt.TextColor3 = Color3.new(1, 1, 0)
                    else
                        cellFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
                        cellTxt.Text = string.format("[%d,%d]\n%s\n%s", tx, ty, name1, name2)
                        if name1 == "AIR" and name2 == "AIR" then
                            cellTxt.TextColor3 = Color3.fromRGB(100, 100, 100)
                        else
                            cellTxt.TextColor3 = Color3.new(1, 1, 1)
                        end
                    end
                end
                index = index + 1
            end
        end
    end

    -- ==========================================
    -- INVENTORY & BUTTON BINDINGS
    -- ==========================================
    local function LoadInventoryList()
        for _, child in pairs(UI.InvScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        local allItems = GetFullInventoryData(); local canvasSize = 0

        if STATE.currentSelectionMode == "IF_CONDITION" then UI.SelectWarn.Text = ">> CLICK ITEM TO SELECT FOR PENYECEKAN <<"
        elseif STATE.currentSelectionMode == "FACTORY_Y1" or STATE.currentSelectionMode == "Y1" then UI.SelectWarn.Text = ">> CLICK BLOCK FOR Y+1 <<"
        elseif STATE.currentSelectionMode == "FARM" or STATE.currentSelectionMode == "FACTORY_FARM" then UI.SelectWarn.Text = ">> CLICK SAPLING FOR FARM <<"
        elseif STATE.currentSelectionMode == "PLACE" or STATE.currentSelectionMode == "FACTORY_PLACE" then UI.SelectWarn.Text = ">> CLICK BLOCK FOR PLACE <<"
        elseif STATE.currentSelectionMode == "FACTORY_DROP" then UI.SelectWarn.Text = ">> CLICK ITEM TO ADD TO FACTORY DROP QUEUE <<"
        else UI.SelectWarn.Text = ">> CLICK ITEM TO CHANGE BOT MENU DROP MODE <<" end
        UI.SelectWarn.Visible = true

        for _, item in ipairs(allItems or {}) do
            local showItem = true
            if (STATE.currentSelectionMode == "FARM" or STATE.currentSelectionMode == "FACTORY_FARM") and item.Type ~= "SAPLING" then showItem = false 
            elseif (STATE.currentSelectionMode == "Y1" or STATE.currentSelectionMode == "FACTORY_Y1" or STATE.currentSelectionMode == "PLACE" or STATE.currentSelectionMode == "FACTORY_PLACE") and item.Type == "SAPLING" then showItem = false end

            if showItem then
                local itemBtn = Instance.new("TextButton", UI.InvScroll)
                itemBtn.Name = tostring(item.Name or "Unknown")
                itemBtn.Size = UDim2.new(1, -10, 0, 30)
                
                if STATE.currentSelectionMode == nil then
                    local mode = STATE.dropConfig[item.Name]
                    itemBtn.Text = string.format("  [%s] %s (x%d)", mode, (item.Name or ""):upper(), item.Amount or 0)
                    if mode == "IGNORE" then itemBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45) elseif mode == "DROP" then itemBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0) elseif mode == "TRASH" then itemBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0) end
                else
                    itemBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35); itemBtn.Text = string.format("  %s (x%d)", (item.Name or ""):upper(), item.Amount or 0)
                end

                itemBtn.TextXAlignment = Enum.TextXAlignment.Left; itemBtn.TextColor3 = (item.Type == "SAPLING") and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 255, 255)
                itemBtn.Font = Enum.Font.GothamBold; itemBtn.TextScaled = true 
                local textConstraint = Instance.new("UITextSizeConstraint", itemBtn); textConstraint.MaxTextSize = 10; textConstraint.MinTextSize = 6
                Instance.new("UICorner", itemBtn).CornerRadius = UDim.new(0, 3)

                itemBtn.MouseButton1Click:Connect(function()
                    if STATE.currentSelectionMode == "FARM" then STATE.farmTargetBlock = item.Name; UI.BtnFarmBlock.Text = string.upper(item.Name); STATE.currentSelectionMode = nil; SwitchTab("Bot")
                    elseif STATE.currentSelectionMode == "PLACE" then STATE.placeTargetBlock = item.Name; UI.BtnPlaceBlock.Text = string.upper(item.Name); STATE.currentSelectionMode = nil; SwitchTab("Bot")
                    elseif STATE.currentSelectionMode == "Y1" then STATE.y1TargetBlock = item.Name; UI.BtnY1Block.Text = string.upper(item.Name); STATE.currentSelectionMode = nil; SwitchTab("Bot")
                    elseif STATE.currentSelectionMode == "FACTORY_Y1" then table.insert(STATE.factoryQueue, "Y1:" .. item.Name); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr(); STATE.currentSelectionMode = nil; SwitchTab("Factory")
                    elseif STATE.currentSelectionMode == "FACTORY_PLACE" then table.insert(STATE.factoryQueue, "PLACE:" .. item.Name); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr(); STATE.currentSelectionMode = nil; SwitchTab("Factory")
                    elseif STATE.currentSelectionMode == "FACTORY_FARM" then
                        local sy = UI.InpFactFarmY1.Text ~= "" and UI.InpFactFarmY1.Text or "60"
                        local ey = UI.InpFactFarmY2.Text ~= "" and UI.InpFactFarmY2.Text or "6"
                        local timer = UI.InpFactFarmTimer.Text ~= "" and UI.InpFactFarmTimer.Text or "30"
                        table.insert(STATE.factoryQueue, "FARM:" .. item.Name .. ":" .. sy .. ":" .. ey .. ":" .. timer)
                        UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr(); STATE.currentSelectionMode = nil; SwitchTab("Factory")
                    elseif STATE.currentSelectionMode == "FACTORY_DROP" then
                        table.insert(STATE.factoryQueue, "DROP:" .. item.Name); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr(); STATE.currentSelectionMode = nil; SwitchTab("Factory")
                    elseif STATE.currentSelectionMode == "IF_CONDITION" then STATE.ifTargetItem = item.Name; UI.BtnFactChkItem.Text = string.upper(item.Name); STATE.currentSelectionMode = nil; SwitchTab("Factory")
                    else
                        if STATE.dropConfig[item.Name] == "IGNORE" then STATE.dropConfig[item.Name] = "DROP" elseif STATE.dropConfig[item.Name] == "DROP" then STATE.dropConfig[item.Name] = "TRASH" else STATE.dropConfig[item.Name] = "IGNORE" end
                        local newMode = STATE.dropConfig[item.Name]
                        itemBtn.Text = string.format("  [%s] %s (x%d)", newMode, (item.Name or ""):upper(), item.Amount or 0)
                        if newMode == "IGNORE" then itemBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45) elseif newMode == "DROP" then itemBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 0) elseif newMode == "TRASH" then itemBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0) end
                    end
                end)
                canvasSize = canvasSize + 34
            end
        end
        UI.InvScroll.CanvasSize = UDim2.new(0, 0, 0, canvasSize)
    end

    UI.BtnFactClear.MouseButton1Click:Connect(function() table.insert(STATE.factoryQueue, "CLEAR"); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr() end)
    UI.BtnFactLoot.MouseButton1Click:Connect(function() table.insert(STATE.factoryQueue, "LOOT"); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr() end)
    UI.BtnFactStop.MouseButton1Click:Connect(function() table.insert(STATE.factoryQueue, "STOP"); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr() end)
    
    UI.BtnFactY1.MouseButton1Click:Connect(function() STATE.currentSelectionMode = "FACTORY_Y1"; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)
    UI.BtnFactPlace.MouseButton1Click:Connect(function() STATE.currentSelectionMode = "FACTORY_PLACE"; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)
    UI.BtnFactFarm.MouseButton1Click:Connect(function() STATE.currentSelectionMode = "FACTORY_FARM"; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)
    UI.BtnFactDropSel.MouseButton1Click:Connect(function() STATE.currentSelectionMode = "FACTORY_DROP"; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)

    UI.BtnFactMove.MouseButton1Click:Connect(function()
        local mx, my = UI.InpFactMoveX.Text, UI.InpFactMoveY.Text
        if mx ~= "" and my ~= "" then table.insert(STATE.factoryQueue, "MOVE:" .. mx .. ":" .. my); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr() end
    end)

    local ops = {">=", "<=", ">", "<", "=="}; local opIdx = 1
    UI.BtnFactChkOp.MouseButton1Click:Connect(function() opIdx = opIdx + 1; if opIdx > #ops then opIdx = 1 end; UI.BtnFactChkOp.Text = ops[opIdx] end)
    UI.BtnFactChkItem.MouseButton1Click:Connect(function() STATE.currentSelectionMode = "IF_CONDITION"; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)
    
    UI.BtnFactChkAdd.MouseButton1Click:Connect(function()
        local item = STATE.ifTargetItem; local val = UI.InpFactChkAmt.Text
        if item ~= "" and val ~= "" then table.insert(STATE.factoryQueue, "CHECK:" .. item .. ":" .. UI.BtnFactChkOp.Text .. ":" .. val); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr() end
    end)

    UI.BtnFactLoopStart.MouseButton1Click:Connect(function()
        local limit = tonumber(UI.InpFactLoopLim.Text) or 0
        table.insert(STATE.factoryQueue, "LOOP_START:" .. limit); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr()
    end)
    UI.BtnFactLoopEnd.MouseButton1Click:Connect(function() table.insert(STATE.factoryQueue, "LOOP_END"); UI.FactoryQueueVisual.Text = "QUEUE: " .. RenderFactoryQueueStr() end)

    local function DisableAllBots()
        STATE.autoClear = false; UI.BtnClear.Text = "CLEAR: OFF"; UI.BtnClear.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        STATE.autoFarm = false; UI.BtnFarm.Text = "FARM: OFF"; UI.BtnFarm.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        STATE.autoPlace = false; UI.BtnPlace.Text = "PLACE: OFF"; UI.BtnPlace.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        STATE.autoY1 = false; UI.BtnY1.Text = "Y+1: OFF"; UI.BtnY1.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        STATE.autoLoot = false; UI.BtnLoot.Text = "LOOT: OFF"; UI.BtnLoot.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        STATE.autoDrop = false; UI.UI_BtnDrop.Text = "DROP: OFF"; UI.UI_BtnDrop.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        STATE.autoMove = false; STATE.factoryMoveX = 0; STATE.factoryMoveY = 0; STATE.isPosLocked = false 
        STATE.factoryForceStopTask = false
        
        _G.CurrentSmartPath = nil; PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false
        STATE.lootQueue = {}; STATE.globalTargetLoot = nil
        STATE.placeQueue = {}
        STATE.actionQueue = {}; STATE.botPhase = "IDLE" 
        STATE.reachableDrops = 0; STATE.radarTotalDrops = 0
        _G.Y1EmptyTimer = nil
        
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid.WalkSpeed = 16
        end
    end

    local function TurnOffBot(reason)
        DisableAllBots(); STATE.isFactoryRunning = false; UI.BtnStartFactory.Text = "▶ START PABRIK"; UI.BtnStartFactory.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
        _G.CurrentStatus = "STATUS: STOPPED - " .. tostring(reason or "")
        if UI.GlobalStatus then UI.GlobalStatus.Text = _G.CurrentStatus end
    end

    UI.BtnStartFactory.MouseButton1Click:Connect(function()
        if #STATE.factoryQueue == 0 then _G.CurrentStatus = "STATUS: ANTREAN PABRIK KOSONG!"; if UI.GlobalStatus then UI.GlobalStatus.Text = _G.CurrentStatus end return end
        STATE.isFactoryRunning = not STATE.isFactoryRunning
        if STATE.isFactoryRunning then
            UI.BtnStartFactory.Text = "⏹ STOP PABRIK"; UI.BtnStartFactory.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            STATE.currentFactoryIndex = 1; STATE.factoryLoopCount = 0; STATE.factoryLoopStartIndex = 1; STATE.factoryLoopLimit = 0; STATE.activeFactoryTask = nil; DisableAllBots()
            _G.CurrentStatus = "STATUS: MESIN PABRIK DIMULAI..."
        else TurnOffBot("PABRIK DIHENTIKAN MANUAL") end
    end)

    UI.BtnClearQueue.MouseButton1Click:Connect(function() STATE.factoryQueue = {}; UI.FactoryQueueVisual.Text = "QUEUE: [EMPTY]"; if STATE.isFactoryRunning then TurnOffBot("PABRIK DIRESET") end end)

    UI.SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
        local query = UI.SearchBar.Text:lower()
        for _, btn in pairs(UI.InvScroll:GetChildren()) do
            if btn:IsA("TextButton") then btn.Visible = (query == "" or (btn.Name or ""):lower():find(query)) end
        end
    end)

    UI.BtnClear.MouseButton1Click:Connect(function() 
        local ns = not STATE.autoClear; DisableAllBots(); STATE.autoClear = ns; 
        if STATE.isFactoryRunning then TurnOffBot("MANUAL OVERRIDE") end; 
        if STATE.autoClear then 
            STATE.lastScan = 0 
            STATE.clearStartX = tonumber(UI.InpClearX1.Text) or 0
            STATE.clearEndX = tonumber(UI.InpClearX2.Text) or 100
            STATE.clearStartY = tonumber(UI.InpClearY1.Text) or 60
            STATE.clearEndY = tonumber(UI.InpClearY2.Text) or 0
            UI.BtnClear.Text = "CLEAR: ON"; UI.BtnClear.BackgroundColor3 = Color3.fromRGB(0, 150, 0) 
        end 
    end)
    
    UI.BtnFarm.MouseButton1Click:Connect(function() 
        local ns = not STATE.autoFarm; DisableAllBots(); STATE.autoFarm = ns; 
        if STATE.isFactoryRunning then TurnOffBot("MANUAL OVERRIDE") end; 
        if STATE.autoFarm then 
            STATE.lastScan = 0; 
            STATE.farmStartY = tonumber(UI.InpFarmY1.Text) or 60; 
            STATE.farmEndY = tonumber(UI.InpFarmY2.Text) or 6; 
            STATE.customFarmTimer = tonumber(UI.InpFarmTimer.Text) or 30;
            STATE.actionQueue = {}; STATE.botPhase = "IDLE"
            UI.BtnFarm.Text = "FARM: ON"; UI.BtnFarm.BackgroundColor3 = Color3.fromRGB(0, 150, 0) 
        end 
    end)
    
    UI.BtnPlace.MouseButton1Click:Connect(function() 
        local ns = not STATE.autoPlace; DisableAllBots(); STATE.autoPlace = ns; 
        if STATE.isFactoryRunning then TurnOffBot("MANUAL OVERRIDE") end; 
        if STATE.autoPlace then 
            STATE.lastScan = 0; STATE.placeQueue = {}; 
            STATE.farmStartY = tonumber(UI.InpFarmY1.Text) or 60; 
            STATE.farmEndY = tonumber(UI.InpFarmY2.Text) or 6;
            UI.BtnPlace.Text = "PLACE: ON"; UI.BtnPlace.BackgroundColor3 = Color3.fromRGB(0, 150, 0) 
        end 
    end)

    UI.BtnY1.MouseButton1Click:Connect(function() local ns = not STATE.autoY1; DisableAllBots(); STATE.autoY1 = ns; if STATE.isFactoryRunning then TurnOffBot("MANUAL OVERRIDE") end; if STATE.autoY1 then STATE.lastScan = 0; STATE.lockedCoordX = tonumber(UI.InpY1X.Text); STATE.lockedCoordY = tonumber(UI.InpY1Y.Text); STATE.isPosLocked = (STATE.lockedCoordX ~= nil and STATE.lockedCoordY ~= nil); UI.BtnY1.Text = "Y+1: ON"; UI.BtnY1.BackgroundColor3 = Color3.fromRGB(0, 150, 0) else STATE.isPosLocked = false end end)
    UI.BtnLoot.MouseButton1Click:Connect(function() local ns = not STATE.autoLoot; DisableAllBots(); STATE.autoLoot = ns; if STATE.isFactoryRunning then TurnOffBot("MANUAL OVERRIDE") end; if STATE.autoLoot then STATE.lastScan = 0; UI.BtnLoot.Text = "LOOT: ON"; UI.BtnLoot.BackgroundColor3 = Color3.fromRGB(0, 150, 0) end end)
    
    UI.UI_BtnDrop.MouseButton1Click:Connect(function() 
        local ns = not STATE.autoDrop
        DisableAllBots()
        STATE.autoDrop = ns
        if STATE.isFactoryRunning then TurnOffBot("MANUAL OVERRIDE") end
        if STATE.autoDrop then 
            STATE.lastScan = 0
            STATE.dropCoordX = tonumber(UI.InpDropX.Text) or 0
            STATE.dropCoordY = tonumber(UI.InpDropY.Text) or 0
            UI.UI_BtnDrop.Text = "DROP: ON"
            UI.UI_BtnDrop.BackgroundColor3 = Color3.fromRGB(0, 150, 0) 
        else 
            UI.UI_BtnDrop.Text = "DROP: OFF"
            UI.UI_BtnDrop.BackgroundColor3 = Color3.fromRGB(120, 0, 0) 
            _G.CurrentSmartPath = nil
        end 
    end)
    
    UI.BtnSaplingSensor.MouseButton1Click:Connect(function() STATE.saplingSensorOnly = not STATE.saplingSensorOnly; if STATE.saplingSensorOnly then UI.BtnSaplingSensor.Text = "SENSOR SAPLING ONLY: ON"; UI.BtnSaplingSensor.BackgroundColor3 = Color3.fromRGB(0, 150, 0) else UI.BtnSaplingSensor.Text = "SENSOR SAPLING ONLY: OFF"; UI.BtnSaplingSensor.BackgroundColor3 = Color3.fromRGB(120, 0, 0) end end)

    UI.BtnFarmBlock.MouseButton1Click:Connect(function() STATE.currentSelectionMode = "FARM"; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)
    UI.BtnPlaceBlock.MouseButton1Click:Connect(function() STATE.currentSelectionMode = "PLACE"; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)
    UI.BtnY1Block.MouseButton1Click:Connect(function() STATE.currentSelectionMode = "Y1"; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)
    UI.BtnDropConfig.MouseButton1Click:Connect(function() STATE.currentSelectionMode = nil; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)

    UI.TabHomeBtn.MouseButton1Click:Connect(function() SwitchTab("Home") end)
    UI.TabRadarBtn.MouseButton1Click:Connect(function() SwitchTab("Radar") end)
    UI.TabBotBtn.MouseButton1Click:Connect(function() SwitchTab("Bot") end)
    UI.TabFactoryBtn.MouseButton1Click:Connect(function() SwitchTab("Factory") end)
    UI.TabInvBtn.MouseButton1Click:Connect(function() STATE.currentSelectionMode = nil; UI.SearchBar.Text = ""; LoadInventoryList(); SwitchTab("Inv") end)
    UI.TabSettingsBtn.MouseButton1Click:Connect(function() SwitchTab("Settings") end)
    SwitchTab("Home")

    UI.BtnMin.MouseButton1Click:Connect(function()
        STATE.isMinimized = not STATE.isMinimized
        if STATE.isMinimized then 
            UI.MainFrame.Size = UDim2.new(0, 450, 0, 50)
            UI.TabContainer.Visible = false
            UI.PageContainer.Visible = false
            
            UI.GlobalStatus.Size = UDim2.new(1, 0, 0, 20)
            UI.GlobalStatus.Position = UDim2.new(0, 0, 1, -20)
            
            UI.BtnMin.Text = "+"
        else 
            UI.MainFrame.Size = UDim2.new(0, 450, 0, 320)
            UI.TabContainer.Visible = true
            UI.PageContainer.Visible = true
            
            UI.GlobalStatus.Size = UDim2.new(1, -90, 0, 20)
            UI.GlobalStatus.Position = UDim2.new(0, 90, 1, -20)
            
            UI.BtnMin.Text = "-" 
        end
    end)
    UI.BtnClose.MouseButton1Click:Connect(function() UI.Screen:Destroy() end)

    -- ==========================================
    -- SHARED: ALGORITMA SNAKE PATH
    -- ==========================================
    local function SortRowByNearestEndpoint(row, lastEndX)
        if #row == 0 then return row end
        local rowLeftX  = row[1].x
        local rowRightX = row[#row].x
        if math.abs(lastEndX - rowLeftX) <= math.abs(lastEndX - rowRightX) then
            return row
        else
            local reversed = {}
            for i = #row, 1, -1 do table.insert(reversed, row[i]) end
            return reversed
        end
    end

    -- ==========================================
    -- SCANNER
    -- ==========================================
    local function ScanForDropsAndGems(cx, cy, dropsList, isPureLoot, totalAirInMap)
        local dropCount, gemCount = 0, 0
        local rawDrops = {}
        STATE.gLootCache = {} 
        
        for _, fName in pairs({"Drops", "Gems", "Items"}) do
            local folder = workspace:FindFirstChild(fName)
            if folder then
                for _, item in pairs(folder:GetChildren() or {}) do
                    local p = GetItemPos(item) 
                    if p then
                        local lx, ly = math.floor(p.X / TILE_SIZE + 0.5), math.floor(p.Y / TILE_SIZE + 0.5)
                        local dropId = item:GetAttribute("id") or item:GetAttribute("Id") or item.Name or ""
                        local itemName = tostring(dropId):upper()
                        local key = lx .. "_" .. ly
                        local isGems = (fName == "Gems" or string.find(itemName, "GEMS") or string.find(itemName, "GEM"))
                        
                        local itemAmt = tonumber(item:GetAttribute("amount")) or tonumber(item:GetAttribute("Amount")) or 1
                        local amtNode = item:FindFirstChild("Amount") or item:FindFirstChild("amount")
                        if amtNode and (amtNode:IsA("IntValue") or amtNode:IsA("NumberValue")) then
                            itemAmt = amtNode.Value
                        end
                        
                        if isPureLoot and not IsWalkableAir(lx, ly, cy) then
                            continue 
                        end
                        
                        if isGems then 
                            STATE.gLootCache[key] = "GEMS"
                            gemCount = gemCount + itemAmt 
                        else 
                            STATE.gLootCache[key] = "ITEM"
                            dropCount = dropCount + itemAmt 
                            if dropsList then dropsList[itemName] = (dropsList[itemName] or 0) + itemAmt end
                        end

                        local isSapling = string.find(itemName, "SAPLING") or string.find(itemName, "SEED")
                        if STATE.saplingSensorOnly and not isSapling and not isGems then continue end
                        local lootKey = "LOOT_" .. lx .. "_" .. ly
                        
                        if lx >= -5 and lx <= 105 and ly >= -5 and ly <= 65 then
                            if not (_G.BlacklistedNodes[lootKey] and os.clock() < _G.BlacklistedNodes[lootKey]) then
                                rawDrops[key] = {
                                    pos = p, x = lx, y = ly, key = lootKey, inst = item,
                                    itemName = itemName
                                }
                            end
                        end
                    end
                end
            end
        end
        
        STATE.radarTotalDrops = gemCount + dropCount
        local tempQueue = {}
        
        local scannedAirCount = 0
        local reachableCount = 0
        local remainingDropsToMap = 0
        for _ in pairs(rawDrops) do remainingDropsToMap = remainingDropsToMap + 1 end

        if isPureLoot and remainingDropsToMap > 0 then
            local queue = {{x=cx, y=cy, dist=0}, {x=cx, y=cy+1, dist=0}}
            local visited = {}
            visited[cx.."_"..cy] = true
            visited[cx.."_"..(cy+1)] = true
            local head = 1
            
            while head <= #queue do
                local curr = queue[head]
                head = head + 1
                
                local key = curr.x.."_"..curr.y
                if rawDrops[key] then
                    local dropData = rawDrops[key]
                    dropData.dist = curr.dist
                    dropData.isLaser = true 
                    table.insert(tempQueue, dropData)
                    rawDrops[key] = nil 
                    reachableCount = reachableCount + 1
                    remainingDropsToMap = remainingDropsToMap - 1
                end

                if remainingDropsToMap <= 0 then break end
                
                local neighbors = {
                    {x=curr.x+1, y=curr.y}, {x=curr.x-1, y=curr.y},
                    {x=curr.x, y=curr.y+1}, {x=curr.x, y=curr.y-1}
                }
                
                for _, n in ipairs(neighbors) do
                    if n.x >= -5 and n.x <= 105 and n.y >= -5 and n.y <= 65 then
                        local nKey = n.x.."_"..n.y
                        if not visited[nKey] then
                            if IsWalkableAir(n.x, n.y, curr.y) and not IsHazard(n.x, n.y) then
                                visited[nKey] = true
                                scannedAirCount = scannedAirCount + 1
                                table.insert(queue, {x=n.x, y=n.y, dist=curr.dist+1})
                            end
                        end
                    end
                end
            end
            
            STATE.lastBfsScannedAir = scannedAirCount
            STATE.lastBfsTotalAir = totalAirInMap
            STATE.reachableDrops = reachableCount
            
            if UI.GlobalStatus and not STATE.globalTargetLoot then
                UI.GlobalStatus.Text = string.format("STATUS: MENGKALKULASI BFS (AIR SCANNED: %d | UNMAPPED: %d)", scannedAirCount, remainingDropsToMap)
            end

            table.sort(tempQueue, function(a, b) return a.dist < b.dist end)

        else
            for k, dropData in pairs(rawDrops) do
                dropData.dist = math.abs(cx - dropData.x) + math.abs(cy - dropData.y)
                table.insert(tempQueue, dropData)
            end
            table.sort(tempQueue, function(a, b) return a.dist < b.dist end)
        end
        
        if #STATE.lootQueue == 0 or not STATE.globalTargetLoot then
            STATE.lootQueue = tempQueue
        else
            local validQueue = {}
            for _, q in ipairs(STATE.lootQueue) do
                if q.inst and q.inst.Parent then
                    table.insert(validQueue, q)
                end
            end
            STATE.lootQueue = validQueue
        end

        return gemCount, dropCount
    end

    local function FullWorldScanExact(cx, cy, isPureLoot)
        local d = { 
            TANAM = 0, GEMS = 0, DROPS = 0,
            BlocksList = {}, SaplingsList = {}, DropsList = {}, LocksList = {}, HazardsList = {}
        }
        
        local totalAirInMap = 0

        for x = -5, 105 do 
            for y = -5, 65 do 
                local t = WorldManager.GetTile(x, y, 1); local bg = WorldManager.GetTile(x, y, 2); local b = WorldManager.GetTile(x, y-1, 1)
                local n = GetSafeName(t); local nb = GetSafeName(bg); local nameBelow = GetSafeName(b)
                
                if n == "AIR" then
                    totalAirInMap = totalAirInMap + 1
                end

                if n ~= "AIR" then
                    if string.find(n, "LOCK") or string.find(n, "BEDROCK") then d.LocksList[n] = (d.LocksList[n] or 0) + 1
                    elseif string.find(n, "MAGMA") then d.HazardsList[n] = (d.HazardsList[n] or 0) + 1
                    elseif string.find(n, "TREE") or string.find(n, "SAPLING") then d.SaplingsList[n] = (d.SaplingsList[n] or 0) + 1
                    else d.BlocksList[n] = (d.BlocksList[n] or 0) + 1 end
                end

                if nb ~= "AIR" then
                    if string.find(nb, "LOCK") then d.LocksList[nb] = (d.LocksList[nb] or 0) + 1
                    else d.BlocksList[nb] = (d.BlocksList[nb] or 0) + 1 end
                end
                
                local pKey = x.."_"..y
                if STATE.TreeTracker[pKey] then
                    local isPending = _G.PendingPlants[pKey] and os.clock() < _G.PendingPlants[pKey]
                    if not isPending and not (n:find("TREE") or n:find("SAPLING") or n:find("SEED")) then
                        STATE.TreeTracker[pKey] = nil
                    end
                end

                if CanPlantAt(x, y) then d.TANAM = d.TANAM + 1 end
            end
        end
        
        local gems, drops = ScanForDropsAndGems(cx, cy, d.DropsList, isPureLoot, totalAirInMap)
        d.GEMS = gems; d.DROPS = drops
        return d
    end

    local function UpdateAnalyticsCards(data)
        local function DictToStr(dict)
            local str = ""; local total = 0
            for k, v in pairs(dict or {}) do str = str .. string.format("- [%d] %s\n", v, k); total = total + v end
            return (str == "" and "- Empty\n" or str), total
        end

        local lockStr, lockT = DictToStr(data.LocksList)
        local sapStr, sapT = DictToStr(data.SaplingsList)
        local dropStr, dropT = DictToStr(data.DropsList)
        local blockStr, blockT = DictToStr(data.BlocksList)
        local hazStr, hazT = DictToStr(data.HazardsList)

        UI.AnalyticsCards["🌍 WORLD STATS"].Text.Text = string.format("🚜 Can Plant: %d\n💎 Floating Gems: %d\n\n- Bots: %s\n- Target Farm: %s\n- Phase Farm: %s", data.TANAM or 0, data.GEMS or 0, (STATE.isFactoryRunning and "PABRIK" or "MANUAL"), string.upper(STATE.farmTargetBlock or "KOSONG"), STATE.botPhase)
        
        UI.AnalyticsCards["📦 DROPS"].Text.Text = string.format("Total: %d\n\n%s", dropT, dropStr)
        UI.AnalyticsCards["📦 DROPS"].Scroll.CanvasSize = UDim2.new(0,0,0, (dropT == 0 and 50 or 20 * #string.split(dropStr, "\n")))

        UI.AnalyticsCards["🔒 PROTECTED"].Text.Text = string.format("Total: %d\n\n%s", lockT, lockStr)
        UI.AnalyticsCards["🔒 PROTECTED"].Scroll.CanvasSize = UDim2.new(0,0,0, (lockT == 0 and 50 or 20 * #string.split(lockStr, "\n")))

        UI.AnalyticsCards["🟫 BLOCKS & BG"].Text.Text = string.format("Total: %d\n\n%s", blockT, blockStr)
        UI.AnalyticsCards["🟫 BLOCKS & BG"].Scroll.CanvasSize = UDim2.new(0,0,0, (blockT == 0 and 50 or 20 * #string.split(blockStr, "\n")))

        -- ==========================================
        -- HOME PLANT TRACKER (ANALYTICS UPDATE)
        -- ==========================================
        local totalTracked = 0
        local totalReady = 0
        local totalGrowing = 0
        local minWait = math.huge
        
        local currentTime = os.time()
        for k, v in pairs(STATE.TreeTracker or {}) do
            totalTracked = totalTracked + 1
            if currentTime >= v then
                totalReady = totalReady + 1
            else
                totalGrowing = totalGrowing + 1
                local wait = v - currentTime
                if wait < minWait then minWait = wait end
            end
        end
        
        local timerStr = (minWait == math.huge) and "Tidak Ada Pohon Ditanam" or FormatTimeID(minWait)

        UI.AnalyticsCards["🌱 PLANTS"].Text.Text = string.format(
            "Scan Total: %d\nTracked: %d\nReady (Harvest): %d\nProcess (Grow): %d\nPanen Berikutnya:\n> %s\n\n%s", 
            sapT, totalTracked, totalReady, totalGrowing, timerStr, sapStr
        )
        UI.AnalyticsCards["🌱 PLANTS"].Scroll.CanvasSize = UDim2.new(0,0,0, 100 + (20 * #string.split(sapStr, "\n")))

        UI.AnalyticsCards["⚠️ HAZARDS"].Text.Text = string.format("Total: %d\n\n%s", hazT, hazStr)
        UI.AnalyticsCards["⚠️ HAZARDS"].Scroll.CanvasSize = UDim2.new(0,0,0, (hazT == 0 and 50 or 20 * #string.split(hazStr, "\n")))
    end

    -- ==========================================
    -- BUILD AUTO FARM QUEUE
    -- ==========================================
    local function BuildFarmQueue(cx, cy)
        local tempPlantQueue = {}
        local tempHarvestQueue = {}
        local farmLootQueue = {}
        local minWaitTime = math.huge
        local hasGrowingTrees = false

        local startY = math.min(STATE.farmStartY, STATE.farmEndY)
        local endY = math.max(STATE.farmStartY, STATE.farmEndY)
        local stepY = 1

        local plantLastEndX = cx
        local harvestLastEndX = cx
        local hasSeed = GetInventorySlot(STATE.farmTargetBlock) ~= nil

        for y = startY, endY, stepY do
            local rowPlants = {}
            local rowHarvests = {}

            for x = 0, 99 do
                local pKey = x.."_"..y
                local readyTime = STATE.TreeTracker[pKey]
                if readyTime then
                    local tName = GetSafeName(WorldManager.GetTile(x, y, 1))
                    if tName == "AIR" then
                        STATE.TreeTracker[pKey] = nil
                    else
                        hasGrowingTrees = true
                        if os.time() >= readyTime then
                            table.insert(rowHarvests, {x = x, y = y, action = "HARVEST"})
                        else
                            if readyTime < minWaitTime then minWaitTime = readyTime end
                        end
                    end
                else
                    if CanPlantAt(x, y) and hasSeed then
                        table.insert(rowPlants, {x = x, y = y, action = "PLANT"})
                    end
                end
            end

            if #rowPlants > 0 then
                rowPlants = SortRowByNearestEndpoint(rowPlants, plantLastEndX)
                for _, item in ipairs(rowPlants) do table.insert(tempPlantQueue, item) end
                plantLastEndX = rowPlants[#rowPlants].x
            end

            if #rowHarvests > 0 then
                rowHarvests = SortRowByNearestEndpoint(rowHarvests, harvestLastEndX)
                for _, item in ipairs(rowHarvests) do table.insert(tempHarvestQueue, item) end
                harvestLastEndX = rowHarvests[#rowHarvests].x
            end
        end

        for _, fName in pairs({"Drops", "Gems", "Items"}) do
            local folder = workspace:FindFirstChild(fName)
            if folder then
                for _, item in pairs(folder:GetChildren() or {}) do
                    local p = GetItemPos(item)
                    if p then
                        local lx, ly = math.floor(p.X / TILE_SIZE + 0.5), math.floor(p.Y / TILE_SIZE + 0.5)
                        if lx >= 0 and lx <= 99 and ly >= startY and ly <= endY + 1 then
                            table.insert(farmLootQueue, {x = lx, y = ly, action = "FARM_LOOT", inst = item})
                        end
                    end
                end
            end
        end

        if #tempHarvestQueue > 0 then
            STATE.botPhase = "HARVESTING"
            return tempHarvestQueue
        elseif #farmLootQueue > 0 then
            STATE.botPhase = "LOOTING_FARM"
            local groupedLoot = {}
            for _, l in ipairs(farmLootQueue) do
                if not groupedLoot[l.y] then groupedLoot[l.y] = {} end
                table.insert(groupedLoot[l.y], l)
            end
            local finalLootQ = {}
            local lastX = cx
            for y = startY, endY + 1 do
                if groupedLoot[y] then
                    local row = SortRowByNearestEndpoint(groupedLoot[y], lastX)
                    for _, i in ipairs(row) do table.insert(finalLootQ, i) end
                    lastX = row[#row].x
                end
            end
            return finalLootQ
        elseif #tempPlantQueue > 0 then
            STATE.botPhase = "PLANTING"
            return tempPlantQueue
        elseif hasGrowingTrees then
            STATE.botPhase = "WAITING"
            local homeX = 0
            for x = 0, 99 do
                local isSolidG = GetSafeName(WorldManager.GetTile(x, startY - 1, 1)) ~= "AIR"
                local isAirA = GetSafeName(WorldManager.GetTile(x, startY, 1)) == "AIR"
                if isSolidG and isAirA then homeX = x; break end
            end
            return {{x = homeX, y = startY, action = "WAIT", waitTime = minWaitTime}}
        else
            STATE.botPhase = "IDLE"
            return {}
        end
    end

    -- ==========================================
    -- AUTO PLACE QUEUE 
    -- ==========================================
    local function BuildPlaceQueue(cx, cy)
        local startY = math.min(STATE.farmStartY, STATE.farmEndY)
        local endY = math.max(STATE.farmStartY, STATE.farmEndY)
        local stepY = 1
        local tempQueue = {}
        local lastEndX = cx

        for y = startY, endY, stepY do
            local rowBuilds = {}
            if y % 2 ~= 0 then
                for x = 1, 99 do
                    local tName = GetSafeName(WorldManager.GetTile(x, y, 1))
                    if tName == "AIR" and not IsProtected(x, y) then
                        table.insert(rowBuilds, {x = x, y = y})
                    end
                end
            end

            if #rowBuilds > 0 then
                rowBuilds = SortRowByNearestEndpoint(rowBuilds, lastEndX)
                for _, item in ipairs(rowBuilds) do table.insert(tempQueue, item) end
                lastEndX = rowBuilds[#rowBuilds].x
            end
        end
        return tempQueue
    end

    -- ==========================================
    -- HEARTBEAT ENGINE: PATHFINDING & STATE MACHINE
    -- ==========================================
    runService.Heartbeat:Connect(function()
        if not UI.Screen.Parent then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local cx = math.floor(root.Position.X / TILE_SIZE + 0.5)
        local cy = math.floor(root.Position.Y / TILE_SIZE + 0.5)

        _G.CurrentStatus = "STATUS: IDLE"
        UI.LblLoc.Text = string.format("LOCATION: X: %d | Y: %d", cx, cy)
        
        if UI.PageRadar.Visible and tick() - STATE.lastRadarScan > 0.2 then
            UpdateRadarUI(cx, cy)
            STATE.lastRadarScan = tick()
        end

        if tick() - STATE.lastScan > 3 then 
            local isPureLoot = STATE.autoLoot and not STATE.autoClear
            
            if #STATE.lootQueue == 0 then
                local gData = FullWorldScanExact(cx, cy, isPureLoot)
                UpdateAnalyticsCards(gData)
            end
            STATE.lastScan = tick() 
        end

        local factoryShouldAdvance = false

        -- ==========================================
        -- FACTORY PIPELINE CONTROLLER
        -- ==========================================
        STATE.factoryForceStopTask = false
        if STATE.isFactoryRunning then
            local currentTask = STATE.factoryQueue[STATE.currentFactoryIndex]
            
            -- FIX V983: CHECK LOOKAHEAD (Soft-Stop)
            local nextTask = STATE.factoryQueue[STATE.currentFactoryIndex + 1]
            if nextTask and string.sub(nextTask, 1, 6) == "CHECK:" then
                if EvaluateIfCondition(nextTask) then 
                    STATE.factoryForceStopTask = true 
                    _G.CurrentStatus = "PABRIK: KONDISI TERPENUHI, MENUNGGU SISA TUGAS SELESAI..."
                end
            end

            if currentTask and string.sub(currentTask, 1, 10) == "LOOP_START" then
                STATE.factoryLoopLimit = tonumber(string.split(currentTask, ":")[2]) or 0
                STATE.factoryLoopStartIndex = STATE.currentFactoryIndex + 1
                STATE.currentFactoryIndex = STATE.currentFactoryIndex + 1
                STATE.factoryLoopCount = 0; STATE.activeFactoryTask = nil
                if STATE.currentFactoryIndex > #STATE.factoryQueue then TurnOffBot("PABRIK SELESAI") end
                return
            elseif currentTask == "LOOP_END" then
                if STATE.factoryLoopLimit > 0 then
                    STATE.factoryLoopCount = STATE.factoryLoopCount + 1
                    if STATE.factoryLoopCount >= STATE.factoryLoopLimit then
                        STATE.currentFactoryIndex = STATE.currentFactoryIndex + 1; STATE.factoryLoopCount = 0
                    else STATE.currentFactoryIndex = STATE.factoryLoopStartIndex end
                else STATE.currentFactoryIndex = STATE.factoryLoopStartIndex end
                STATE.activeFactoryTask = nil
                if STATE.currentFactoryIndex > #STATE.factoryQueue then TurnOffBot("PABRIK SELESAI") end
                return
            elseif currentTask == "STOP" then
                TurnOffBot("PABRIK MENCAPAI TARGET STOP")
                return
            elseif currentTask and string.sub(currentTask, 1, 6) == "CHECK:" then
                if EvaluateIfCondition(currentTask) then factoryShouldAdvance = true else DisableAllBots(); _G.CurrentStatus = "PABRIK MENUNGGU: " .. string.gsub(currentTask, "CHECK:", "") end
            elseif currentTask and string.sub(currentTask, 1, 5) == "MOVE:" then
                local parts = string.split(currentTask, ":"); local tx, ty = tonumber(parts[2]), tonumber(parts[3])
                if tx and ty then
                    local targetWorldX = tx * TILE_SIZE
                    if cx == tx and cy == ty and math.abs(root.Position.X - targetWorldX) <= 0.15 then 
                        factoryShouldAdvance = true 
                    else
                        if STATE.activeFactoryTask ~= currentTask then DisableAllBots(); STATE.activeFactoryTask = currentTask; STATE.autoMove = true; STATE.factoryMoveX = tx; STATE.factoryMoveY = ty end
                    end
                else factoryShouldAdvance = true end
            elseif currentTask and string.sub(currentTask, 1, 5) == "DROP:" then
                if STATE.activeFactoryTask ~= currentTask then
                    DisableAllBots()
                    STATE.activeFactoryTask = currentTask
                    STATE.factoryDropInProgress = true
                    _G.CurrentlyProcessingInv = true
                    
                    local targetDropItem = string.split(currentTask, ":")[2] or ""
                    local slotToDrop = GetInventorySlot(targetDropItem)
                    
                    if slotToDrop then
                        _G.CurrentStatus = "PABRIK MENGGUGURKAN: " .. string.upper(targetDropItem)
                        local itemAmt = Inventory.Stacks[slotToDrop].Amount or 0
                        _G.TargetPromptAmount = itemAmt < 200 and itemAmt or 200
                        PlayerDrop:FireServer(slotToDrop)
                        
                        task.spawn(function()
                            task.wait(1.5)
                            _G.CurrentlyProcessingInv = false
                            STATE.factoryDropInProgress = false
                        end)
                    else
                        _G.CurrentlyProcessingInv = false
                        STATE.factoryDropInProgress = false
                        factoryShouldAdvance = true 
                    end
                elseif not STATE.factoryDropInProgress then
                    factoryShouldAdvance = true 
                end
            elseif currentTask then
                local baseTask = currentTask; local taskArgs = nil
                if string.find(currentTask, ":") then local parts = string.split(currentTask, ":"); baseTask = parts[1]; taskArgs = parts end

                if STATE.activeFactoryTask ~= currentTask then
                    DisableAllBots(); STATE.activeFactoryTask = currentTask
                    if baseTask == "CLEAR" then STATE.autoClear = true 
                    elseif baseTask == "FARM" then 
                        STATE.autoFarm = true 
                        if taskArgs and taskArgs[2] then STATE.farmTargetBlock = taskArgs[2] end
                        if taskArgs and taskArgs[3] then STATE.farmStartY = tonumber(taskArgs[3]) or 60 end
                        if taskArgs and taskArgs[4] then STATE.farmEndY = tonumber(taskArgs[4]) or 6 end
                        if taskArgs and taskArgs[5] then STATE.customFarmTimer = tonumber(taskArgs[5]) or 30 end
                        STATE.actionQueue = {}; STATE.botPhase = "IDLE"
                    elseif baseTask == "LOOT" then STATE.autoLoot = true; STATE.lastScan = 0
                    elseif baseTask == "Y1" then 
                        STATE.autoY1 = true 
                        if taskArgs and taskArgs[2] then STATE.y1TargetBlock = taskArgs[2] end
                        STATE.isPosLocked = true; STATE.lockedCoordX = cx; STATE.lockedCoordY = cy
                    elseif baseTask == "PLACE" then
                        STATE.autoPlace = true; STATE.placeQueue = {}
                        if taskArgs and taskArgs[2] then STATE.placeTargetBlock = taskArgs[2] end 
                    end
                end
            end
        end
        
        _G.CurrentlyBreaking = nil

        -- ==========================================
        -- SINGLE ACTION ENGINE
        -- ==========================================
        local actedOnAction = false

        if STATE.autoClear or STATE.autoFarm or STATE.autoLoot or STATE.autoY1 or STATE.autoMove or STATE.autoDrop or STATE.autoPlace then
            if _G.RegenTime > 0 and os.clock() > _G.RegenTime then _G.MagmaHits = 0; _G.RegenTime = 0 end
            
            local inMagma = IsHazard(cx, cy) or IsHazard(cx, cy-1)
            if inMagma then if os.clock() - _G.LastHitTime > 1.2 then _G.MagmaHits = math.min(10, _G.MagmaHits + 1); _G.LastHitTime = os.clock(); _G.RegenTime = os.clock() + 30 end end
            
            if _G.MagmaHits >= 10 then
                if not inMagma and not IsHazard(cx+1, cy) and not IsHazard(cx-1, cy) then
                    PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false; root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                    _G.CurrentStatus = "STATUS: REGENERATING HEALTH"; if not STATE.isFactoryRunning then UI.GlobalStatus.Text = _G.CurrentStatus end
                    return 
                end
            end

            if _G.EscapeMode and os.clock() < _G.EscapeMode.endTime then PlayerMovement.MoveX = _G.EscapeMode.dir; PlayerMovement.Jumping = true; return elseif _G.EscapeMode then _G.EscapeMode = nil end

            table.insert(_G.PosHistory, {x = cx, y = cy, t = os.clock()})
            local minX, maxX, minY, maxY = cx, cx, cy, cy
            local hasOldPos = false; local newHistory = {}
            for i = 1, #_G.PosHistory do
                if os.clock() - _G.PosHistory[i].t <= 2 then 
                    table.insert(newHistory, _G.PosHistory[i])
                    minX = math.min(minX, _G.PosHistory[i].x); maxX = math.max(maxX, _G.PosHistory[i].x)
                    minY = math.min(minY, _G.PosHistory[i].y); maxY = math.max(maxY, _G.PosHistory[i].y)
                    if os.clock() - _G.PosHistory[i].t > 1.5 then hasOldPos = true end
                end
            end
            _G.PosHistory = newHistory

            local isTryingToAct = (PlayerMovement.MoveX ~= 0 or PlayerMovement.Jumping or _G.PathTargetKey ~= nil or _G.CurrentlyBreaking ~= nil)
            
            local isCurrentlyDropping = false
            if STATE.factoryDropInProgress or (STATE.autoDrop and cx == STATE.dropCoordX and cy == STATE.dropCoordY) then
                isCurrentlyDropping = true
            end
            
            if not STATE.isPosLocked and not isCurrentlyDropping and hasOldPos and (maxX - minX) <= 0.5 and (maxY - minY) <= 1 and isTryingToAct and not STATE.autoY1 then
                _G.PosHistory = {} 
                local moveXFallback = PlayerMovement.MoveX == 0 and 1 or PlayerMovement.MoveX
                local intentDir = moveXFallback > 0 and 1 or -1
                if _G.PathTargetKey then _G.BlacklistedNodes[_G.PathTargetKey] = os.clock() + 15 end
                if _G.CurrentlyBreaking then _G.BlacklistedNodes[_G.CurrentlyBreaking.X .. "_" .. _G.CurrentlyBreaking.Y] = os.clock() + 15 end
                _G.BlacklistedNodes[(cx + intentDir) .. "_" .. cy] = os.clock() + 10
                _G.CurrentSmartPath = nil; _G.CurrentStatus = "STATUS: STUCK 2S! JUMPING & RECALCULATING"
                
                if (STATE.autoClear or STATE.autoMove or STATE.autoPlace) and NeedsBreaking(cx, cy-1, true, cy) then
                    PlayerMovement.MoveX = 0; _G.CurrentlyBreaking = Vector2.new(cx, cy-1); PlayerFist:FireServer(_G.CurrentlyBreaking)
                else _G.EscapeMode = {endTime = os.clock() + 0.5, dir = intentDir * -1}; PlayerMovement.Jumping = true end
                if not STATE.isFactoryRunning then UI.GlobalStatus.Text = _G.CurrentStatus end
                return 
            end
            
            -- 1. MAGMA 5X5 BREAK PRIORITY
            if not actedOnAction and (STATE.autoClear or STATE.autoMove or STATE.autoPlace) then
                local targetMagma = nil
                for dx = -2, 2 do 
                    for dy = -2, 2 do 
                        if IsHazard(cx + dx, cy + dy) then 
                            targetMagma = {x = cx + dx, y = cy + dy}; break 
                        end 
                    end 
                    if targetMagma then break end 
                end
                
                if targetMagma then
                    _G.CurrentlyBreaking = Vector2.new(targetMagma.x, targetMagma.y)
                    PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false; PlayerFist:FireServer(_G.CurrentlyBreaking)
                    _G.CurrentStatus = "Status lock ["..targetMagma.x..", "..targetMagma.y.."] melakukan [BREAK HAZARD 5x5]"; actedOnAction = true
                end
            end

            -- 2. Y+1 LOGIC
            if not actedOnAction and STATE.autoY1 then
                if STATE.y1TargetBlock == "" then
                    if STATE.isFactoryRunning then factoryShouldAdvance = true else TurnOffBot("TARGET Y1 KOSONG!") end
                    actedOnAction = true
                else
                    local lockedX = STATE.isPosLocked and STATE.lockedCoordX or cx
                    local lockedY = STATE.isPosLocked and STATE.lockedCoordY or cy

                    if STATE.isPosLocked and (math.abs(cx - lockedX) > 0 or math.abs(cy - lockedY) > 0) then
                        local targetKey = "Y1_MOVE_" .. lockedX .. "_" .. lockedY
                        if _G.PathTargetKey ~= targetKey or tick() - STATE.lastPathCalc > 0.5 or not _G.CurrentSmartPath then
                            _G.CurrentSmartPath = FindSmartPath(cx, cy, lockedX, lockedY, "LOOT")
                            _G.PathNextStepIndex = 1; _G.PathTargetKey = targetKey; STATE.lastPathCalc = tick()
                        end

                        if _G.CurrentSmartPath then
                            local nextStep = _G.CurrentSmartPath[_G.PathNextStepIndex]
                            if not nextStep and cx == lockedX and cy == lockedY then nextStep = {x = lockedX, y = lockedY} end

                            if nextStep then
                                local targetWorldX = nextStep.x * TILE_SIZE; local tolerance = 1.2
                                local diffX = targetWorldX - root.Position.X
                                if diffX > tolerance then PlayerMovement.MoveX = 1 elseif diffX < -tolerance then PlayerMovement.MoveX = -1
                                else
                                    PlayerMovement.MoveX = 0
                                    if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                                end
                                PlayerMovement.Jumping = (nextStep.y > cy); _G.CurrentStatus = string.format("STATUS: MENCARI JALAN KE Y+1 [X: %d, Y: %d]", lockedX, lockedY)
                                if cx == nextStep.x and cy == nextStep.y and _G.PathNextStepIndex < #_G.CurrentSmartPath then _G.PathNextStepIndex = _G.PathNextStepIndex + 1 end
                            end
                        else
                            local targetWorldX = lockedX * TILE_SIZE
                            local diffX = targetWorldX - root.Position.X
                            if diffX > 1.2 then PlayerMovement.MoveX = 1 elseif diffX < -1.2 then PlayerMovement.MoveX = -1 else
                                PlayerMovement.MoveX = 0
                                if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                            end
                            PlayerMovement.Jumping = (lockedY > cy)
                            _G.CurrentStatus = string.format("STATUS: FORCED MOVE KE Y+1 LOCK [X: %d, Y: %d]", lockedX, lockedY)
                        end
                        actedOnAction = true
                    else
                        local targetBreakX = lockedX
                        local targetBreakY = lockedY + 1
                        
                        local isSafeToMultiply = not IsProtected(targetBreakX, targetBreakY)
                        local blockSlot = GetInventorySlot(STATE.y1TargetBlock)
                        
                        -- Force Stop Factory
                        if STATE.factoryForceStopTask then blockSlot = nil end

                        local tHead = WorldManager.GetTile(targetBreakX, targetBreakY, 1); local tHeadName = GetSafeName(tHead)
                        local isHeadTree = false
                        if string.find(tHeadName, "TREE") or string.find(tHeadName, "SAPLING") then isHeadTree = true end
                        
                        local targetY1Loot = nil; local minDist = math.huge
                        for _, fName in pairs({"Drops", "Gems", "Items"}) do
                            local folder = workspace:FindFirstChild(fName)
                            if folder then
                                for _, item in pairs(folder:GetChildren() or {}) do
                                    local p = GetItemPos(item)
                                    if p and math.abs(p.X / TILE_SIZE - targetBreakX) <= 1.5 and p.Y / TILE_SIZE >= cy and p.Y / TILE_SIZE <= cy + 3.0 then
                                        local dropId = item:GetAttribute("id") or item:GetAttribute("Id") or item.Name or ""; local itemName = tostring(dropId):upper()
                                        local isSapling = string.find(itemName, "SAPLING")
                                        if STATE.saplingSensorOnly and not isSapling and not string.find(itemName, "GEMS") then continue end
                                        local dist = math.abs(p.X - root.Position.X)
                                        if dist < minDist then minDist = dist; targetY1Loot = p end
                                    end
                                end
                            end
                        end

                        -- FIX V983: Soliditas evaluasi. Bot TIDAK AKAN PERNAH stop jika block di depan masih ada!
                        local blockExists = (tHeadName ~= "AIR" and not isHeadTree)
                        local isOutOfItems = (not blockSlot and not blockExists and not targetY1Loot)

                        if not isSafeToMultiply or isOutOfItems then
                            if not _G.Y1EmptyTimer then
                                _G.Y1EmptyTimer = os.clock() + 1.5
                            elseif os.clock() > _G.Y1EmptyTimer then
                                if STATE.isFactoryRunning then factoryShouldAdvance = true else TurnOffBot("OUT OF ITEMS / TUGAS SELESAI") end
                                _G.Y1EmptyTimer = nil
                                actedOnAction = true
                            end
                        else
                            _G.Y1EmptyTimer = nil
                        end

                        if not actedOnAction then
                            local centerX = targetBreakX * TILE_SIZE; local centerDiff = centerX - root.Position.X
                            local tolerance = 1.2
                            
                            if centerDiff > tolerance then 
                                PlayerMovement.MoveX = 1; PlayerMovement.Jumping = false
                                _G.CurrentStatus = string.format("STATUS: PENYELARASAN AKHIR X KE: %d", targetBreakX)
                            elseif centerDiff < -tolerance then 
                                PlayerMovement.MoveX = -1; PlayerMovement.Jumping = false
                                _G.CurrentStatus = string.format("STATUS: PENYELARASAN AKHIR X KE: %d", targetBreakX)
                            else
                                PlayerMovement.MoveX = 0 
                                
                                if math.abs(root.Position.X - centerX) > 0.01 then 
                                    root.CFrame = CFrame.new(centerX, root.Position.Y, root.Position.Z)
                                    root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z)
                                end
                                
                                local isGrounded = (WorldManager.GetTile(targetBreakX, cy - 1, 1) ~= nil) or (WorldManager.GetTile(targetBreakX, cy - 1, 2) ~= nil) or IsProtected(targetBreakX, cy - 1)

                                if targetY1Loot then
                                    if isGrounded and os.clock() - _G.LastY1Jump > 0.15 then
                                        PlayerMovement.Jumping = true
                                        _G.LastY1Jump = os.clock()
                                        root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 42, root.AssemblyLinearVelocity.Z)
                                    elseif os.clock() - _G.LastY1Jump > 0.05 then 
                                        PlayerMovement.Jumping = false 
                                    end
                                    _G.CurrentStatus = "STATUS: LOMPAT AMBIL LOOT (ANTI-MAGNET)"
                                else
                                    if isGrounded then
                                        PlayerMovement.Jumping = false
                                        local now = os.clock()
                                        
                                        -- FIX V983: Bypass nama untuk break. Jika bukan AIR, hajar terus.
                                        if tHeadName ~= "AIR" and not isHeadTree then
                                            if now - _G.LastY1Break >= 0.005 then 
                                                _G.CurrentlyBreaking = Vector2.new(targetBreakX, targetBreakY)
                                                PlayerFist:FireServer(_G.CurrentlyBreaking)
                                                _G.LastY1Break = now
                                            end
                                        else
                                            if blockSlot then
                                                if now - _G.LastMultiplyPlace > 0.05 then 
                                                    PlayerPlaceItem:FireServer(Vector2.new(targetBreakX, targetBreakY), blockSlot)
                                                    _G.LastMultiplyPlace = now 
                                                end
                                            end
                                            
                                            if now - _G.LastY1Break >= 0.005 then 
                                                _G.CurrentlyBreaking = Vector2.new(targetBreakX, targetBreakY)
                                                PlayerFist:FireServer(_G.CurrentlyBreaking)
                                                _G.LastY1Break = now
                                            end
                                        end
                                        _G.CurrentStatus = string.format("Status lock [X: %d, Y: %d] melakukan [BREAK Y+1]", targetBreakX, targetBreakY)
                                    else PlayerMovement.Jumping = false end
                                end
                            end
                            _G.PosHistory = {}; _G.CurrentSmartPath = nil; _G.PathTargetKey = nil; actedOnAction = true
                        end
                    end
                end
            end

            -- 3. AUTO LOOT PURE BFS QUEUE
            if not actedOnAction and STATE.autoLoot and not STATE.autoClear then
                if STATE.globalTargetLoot and (not STATE.globalTargetLoot.inst or not STATE.globalTargetLoot.inst.Parent) then
                    STATE.globalTargetLoot = nil
                    _G.CurrentSmartPath = nil
                end
                
                if not STATE.globalTargetLoot then
                    while #STATE.lootQueue > 0 do
                        local candidate = table.remove(STATE.lootQueue, 1)
                        if candidate.inst and candidate.inst.Parent then
                            STATE.globalTargetLoot = candidate
                            break
                        end
                    end
                end
                
                if not STATE.globalTargetLoot then
                    if STATE.reachableDrops == 0 then
                        PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false
                        local terkurung = (STATE.radarTotalDrops or 0) - (STATE.reachableDrops or 0)
                        local msg = string.format("SEMUA JALUR AIR TERSCAN! %d DROPS TERKUNCI BLOK.", math.max(0, terkurung))
                        
                        if STATE.isFactoryRunning then factoryShouldAdvance = true else TurnOffBot(msg) end
                    else
                        PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false
                        local unmappedAir = (STATE.lastBfsTotalAir or 0) - (STATE.lastBfsScannedAir or 0)
                        _G.CurrentStatus = string.format("STATUS: MENGKALKULASI BFS (SISA %d BLOK AIR DISCAN)", math.max(0, unmappedAir))
                    end
                    actedOnAction = true
                elseif STATE.globalTargetLoot and not STATE.isPosLocked then
                    local targetKey = STATE.globalTargetLoot.key
                    
                    if _G.PathTargetKey ~= targetKey or tick() - STATE.lastPathCalc > 0.5 or not _G.CurrentSmartPath then
                        _G.CurrentSmartPath = FindSmartPath(cx, cy, STATE.globalTargetLoot.x, STATE.globalTargetLoot.y, "AIR_ONLY")
                        _G.PathNextStepIndex = 1; _G.PathTargetKey = targetKey; STATE.lastPathCalc = tick()
                        if not _G.CurrentSmartPath then 
                            _G.BlacklistedNodes[targetKey] = os.clock() + 15
                            STATE.globalTargetLoot = nil 
                        end
                    end
                    
                    if _G.CurrentSmartPath then
                        local nextStep = _G.CurrentSmartPath[_G.PathNextStepIndex] 
                        if not nextStep and cx == STATE.globalTargetLoot.x and cy == STATE.globalTargetLoot.y then nextStep = {x = STATE.globalTargetLoot.x, y = STATE.globalTargetLoot.y} end
                        
                        if nextStep then
                            local targetWorldX = nextStep.x * TILE_SIZE; local tolerance = 1.2 
                            if nextStep.x == STATE.globalTargetLoot.x and nextStep.y == STATE.globalTargetLoot.y then targetWorldX = STATE.globalTargetLoot.pos.X; tolerance = 1.5 end
                            
                            local diffX = targetWorldX - root.Position.X
                            if diffX > tolerance then PlayerMovement.MoveX = 1 elseif diffX < -tolerance then PlayerMovement.MoveX = -1 
                            else
                                PlayerMovement.MoveX = 0
                                if targetWorldX == nextStep.x * TILE_SIZE then
                                    if math.abs(root.AssemblyLinearVelocity.X) > 0.1 then
                                        root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) 
                                    end
                                end
                            end
                            
                            PlayerMovement.Jumping = (nextStep.y > cy)
                            
                            local airScanned = STATE.lastBfsScannedAir or 0
                            local totalAir = STATE.lastBfsTotalAir or 0
                            _G.CurrentStatus = string.format("Looting [%d,%d] (Scanner BFS: %d/%d AIR)", STATE.globalTargetLoot.x, STATE.globalTargetLoot.y, airScanned, totalAir)
                            
                            if cx == nextStep.x and cy == nextStep.y and _G.PathNextStepIndex < #_G.CurrentSmartPath then _G.PathNextStepIndex = _G.PathNextStepIndex + 1 end
                        end
                    end
                    actedOnAction = true
                else PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false; actedOnAction = true end
            end

            -- 4. AUTO MOVE ACTION (FACTORY PATHFINDING)
            if not actedOnAction and STATE.autoMove then
                local targetKey = "FACTORY_MOVE"
                if _G.PathTargetKey ~= targetKey or tick() - STATE.lastPathCalc > 0.5 or not _G.CurrentSmartPath then
                    _G.CurrentSmartPath = FindSmartPath(cx, cy, STATE.factoryMoveX, STATE.factoryMoveY, "LOOT"); _G.PathNextStepIndex = 1; _G.PathTargetKey = targetKey; STATE.lastPathCalc = tick()
                end

                if _G.CurrentSmartPath then
                    local nextStep = _G.CurrentSmartPath[_G.PathNextStepIndex] 
                    if not nextStep and cx == STATE.factoryMoveX and cy == STATE.factoryMoveY then nextStep = {x = STATE.factoryMoveX, y = STATE.factoryMoveY} end
                    
                    if nextStep then
                        -- FIX V983: Pengecekan pathing menggunakan cy (CurrentY)
                        if NeedsBreaking(nextStep.x, nextStep.y, true, cy) then 
                            PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false; _G.CurrentlyBreaking = Vector2.new(nextStep.x, nextStep.y)
                            PlayerFist:FireServer(_G.CurrentlyBreaking); _G.CurrentStatus = "Status lock ["..nextStep.x..", "..nextStep.y.."] melakukan [BREAK BLOCK FOR MOVE]"
                        else
                            local targetWorldX = nextStep.x * TILE_SIZE; local tolerance = 1.2
                            local diffX = targetWorldX - root.Position.X
                            if diffX > tolerance then PlayerMovement.MoveX = 1 elseif diffX < -tolerance then PlayerMovement.MoveX = -1 
                            else
                                PlayerMovement.MoveX = 0
                                if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                            end
                            PlayerMovement.Jumping = (nextStep.y > cy); _G.CurrentStatus = "PABRIK: MENUJU KE X: " .. STATE.factoryMoveX .. " Y: " .. STATE.factoryMoveY
                            if cx == nextStep.x and cy == nextStep.y and _G.PathNextStepIndex < #_G.CurrentSmartPath then _G.PathNextStepIndex = _G.PathNextStepIndex + 1 end
                        end
                    end
                else 
                    local targetWorldX = STATE.factoryMoveX * TILE_SIZE
                    local diffX = targetWorldX - root.Position.X
                    if diffX > 1.2 then PlayerMovement.MoveX = 1 elseif diffX < -1.2 then PlayerMovement.MoveX = -1 else
                        PlayerMovement.MoveX = 0
                        if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                    end
                    PlayerMovement.Jumping = (STATE.factoryMoveY > cy)
                end
                actedOnAction = true
            end

            -- 5. BOT MENU AUTO DROP (SMART PATHING & AUTO-HALT)
            if not actedOnAction and STATE.autoDrop and not STATE.factoryDropInProgress then
                local hasItemsToDrop = false
                for slot, data in pairs(Inventory.Stacks) do
                    if data and data.Id and (data.Amount or 0) > 0 then
                        local name = tostring(ItemsManager.GetName(data.Id) or "")
                        local mode = STATE.dropConfig[name] or "IGNORE"
                        
                        if mode == "DROP" or mode == "TRASH" then
                            hasItemsToDrop = true; break
                        end
                    end
                end

                if hasItemsToDrop then
                    if cx == STATE.dropCoordX and cy == STATE.dropCoordY then
                        _G.PathTargetKey = nil
                        _G.CurrentSmartPath = nil
                        PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false
                        _G.CurrentStatus = "STATUS: DUMPING ITEMS..."
                        ProcessAutoDrop() 
                    else
                        local targetKey = "DROP_MOVE"
                        if _G.PathTargetKey ~= targetKey or tick() - STATE.lastPathCalc > 0.5 or not _G.CurrentSmartPath then
                            _G.CurrentSmartPath = FindSmartPath(cx, cy, STATE.dropCoordX, STATE.dropCoordY, "LOOT")
                            _G.PathNextStepIndex = 1; _G.PathTargetKey = targetKey; STATE.lastPathCalc = tick()
                        end

                        if _G.CurrentSmartPath then
                            local nextStep = _G.CurrentSmartPath[_G.PathNextStepIndex] 
                            if not nextStep and cx == STATE.dropCoordX and cy == STATE.dropCoordY then nextStep = {x = STATE.dropCoordX, y = STATE.dropCoordY} end
                            
                            if nextStep then
                                if NeedsBreaking(nextStep.x, nextStep.y, true, cy) then
                                    PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false; _G.CurrentlyBreaking = Vector2.new(nextStep.x, nextStep.y)
                                    PlayerFist:FireServer(_G.CurrentlyBreaking); _G.CurrentStatus = "STATUS: BREAKING TO DROP LOCATION"
                                else
                                    local targetWorldX = nextStep.x * TILE_SIZE; local tolerance = 1.2
                                    local diffX = targetWorldX - root.Position.X
                                    if diffX > tolerance then PlayerMovement.MoveX = 1 elseif diffX < -tolerance then PlayerMovement.MoveX = -1 
                                    else
                                        PlayerMovement.MoveX = 0
                                        if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                                    end
                                    PlayerMovement.Jumping = (nextStep.y > cy); _G.CurrentStatus = "STATUS: MOVING TO DROP X:" .. STATE.dropCoordX .. " Y:" .. STATE.dropCoordY
                                    if cx == nextStep.x and cy == nextStep.y and _G.PathNextStepIndex < #_G.CurrentSmartPath then _G.PathNextStepIndex = _G.PathNextStepIndex + 1 end
                                end
                            end
                        else
                            local targetWorldX = STATE.dropCoordX * TILE_SIZE
                            local diffX = targetWorldX - root.Position.X
                            if diffX > 1.2 then PlayerMovement.MoveX = 1 elseif diffX < -1.2 then PlayerMovement.MoveX = -1 else
                                PlayerMovement.MoveX = 0
                                if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                            end
                            PlayerMovement.Jumping = (STATE.dropCoordY > cy)
                            _G.CurrentStatus = "STATUS: FORCED MOVE TO DROP"
                        end
                    end
                else
                    _G.CurrentSmartPath = nil
                    PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false
                    if STATE.isFactoryRunning then
                        factoryShouldAdvance = true
                    else
                        STATE.autoDrop = false
                        if UI.UI_BtnDrop then
                            UI.UI_BtnDrop.Text = "DROP: OFF"
                            UI.UI_BtnDrop.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
                        end
                        _G.CurrentStatus = "STATUS: DROP SELESAI - SEMUA ITEM TERDROP"
                    end
                end
                actedOnAction = true
            end

            -- 6. AUTO CLEAR MURNI
            if not actedOnAction and STATE.autoClear then
                local bx, by = GetHighestBlockTarget(cx, cy)
                
                if bx then 
                    if math.abs(bx - cx) <= 1 and math.abs(by - cy) <= 1 then
                        local centerX = cx * TILE_SIZE; local centerDiff = centerX - root.Position.X
                        if not STATE.isPosLocked then
                            if centerDiff > 1.2 then PlayerMovement.MoveX = 1 elseif centerDiff < -1.2 then PlayerMovement.MoveX = -1 else
                                PlayerMovement.MoveX = 0; root.CFrame = CFrame.new(centerX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z)
                            end
                        end
                        PlayerMovement.Jumping = false; _G.CurrentlyBreaking = Vector2.new(bx, by); PlayerFist:FireServer(_G.CurrentlyBreaking)
                        _G.CurrentSmartPath = nil; _G.CurrentStatus = "Status lock ["..bx..", "..by.."] melakukan [BREAK CLEAR MODE]"
                    else
                        if not STATE.isPosLocked then
                            local targetKey = "BLOCK_" .. bx .. "_" .. by
                            if _G.PathTargetKey ~= targetKey or tick() - STATE.lastPathCalc > 0.5 or not _G.CurrentSmartPath then
                                _G.CurrentSmartPath = FindSmartPath(cx, cy, bx, by, "BREAK"); _G.PathNextStepIndex = 1; _G.PathTargetKey = targetKey; STATE.lastPathCalc = tick()
                                if not _G.CurrentSmartPath then
                                    _G.BlacklistedNodes[bx .. "," .. by] = os.clock() + 15
                                end
                            end
                            
                            if _G.CurrentSmartPath and _G.CurrentSmartPath[_G.PathNextStepIndex] then
                                local nextStep = _G.CurrentSmartPath[_G.PathNextStepIndex]
                                if NeedsBreaking(nextStep.x, nextStep.y, true, cy) then 
                                    PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false; _G.CurrentlyBreaking = Vector2.new(nextStep.x, nextStep.y); PlayerFist:FireServer(_G.CurrentlyBreaking)
                                    _G.CurrentStatus = "Status lock ["..nextStep.x..", "..nextStep.y.."] melakukan [BREAK OBSTACLE]"
                                else
                                    local targetWorldX = nextStep.x * TILE_SIZE; local diffX = targetWorldX - root.Position.X
                                    if diffX > 1.2 then PlayerMovement.MoveX = 1 elseif diffX < -1.2 then PlayerMovement.MoveX = -1 else
                                        PlayerMovement.MoveX = 0; root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z)
                                    end
                                    PlayerMovement.Jumping = (nextStep.y > cy); _G.CurrentStatus = "Status lock ["..bx..", "..by.."] melakukan [PATHING TO BLOCK]"
                                    if cx == nextStep.x and cy == nextStep.y then _G.PathNextStepIndex = _G.PathNextStepIndex + 1 end
                                end
                            else
                                local targetWorldX = bx * TILE_SIZE
                                local diffX = targetWorldX - root.Position.X
                                if diffX > 1.2 then PlayerMovement.MoveX = 1 elseif diffX < -1.2 then PlayerMovement.MoveX = -1 else
                                    PlayerMovement.MoveX = 0
                                    if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                                end
                                PlayerMovement.Jumping = (by > cy)
                            end
                        end
                    end
                elseif STATE.globalTargetLoot or #STATE.lootQueue > 0 then
                    if STATE.globalTargetLoot and (not STATE.globalTargetLoot.inst or not STATE.globalTargetLoot.inst.Parent) then
                        STATE.globalTargetLoot = nil; _G.CurrentSmartPath = nil
                    end
                    if not STATE.globalTargetLoot then
                        while #STATE.lootQueue > 0 do
                            local candidate = table.remove(STATE.lootQueue, 1)
                            if candidate.inst and candidate.inst.Parent then
                                STATE.globalTargetLoot = candidate
                                break
                            end
                        end
                    end

                    if STATE.globalTargetLoot and not STATE.isPosLocked then
                        local targetKey = STATE.globalTargetLoot.key
                        if _G.PathTargetKey and not string.find(_G.PathTargetKey, "LOOT") then _G.CurrentSmartPath = nil end
                        
                        if _G.PathTargetKey ~= targetKey or tick() - STATE.lastPathCalc > 0.5 or not _G.CurrentSmartPath then
                            _G.CurrentSmartPath = FindSmartPath(cx, cy, STATE.globalTargetLoot.x, STATE.globalTargetLoot.y, "BREAK"); _G.PathNextStepIndex = 1; _G.PathTargetKey = targetKey; STATE.lastPathCalc = tick()
                            if not _G.CurrentSmartPath then _G.BlacklistedNodes[targetKey] = os.clock() + 15; STATE.globalTargetLoot = nil end
                        end
                        
                        if _G.CurrentSmartPath then
                            local nextStep = _G.CurrentSmartPath[_G.PathNextStepIndex] 
                            if not nextStep and cx == STATE.globalTargetLoot.x and cy == STATE.globalTargetLoot.y then nextStep = {x = STATE.globalTargetLoot.x, y = STATE.globalTargetLoot.y} end
                            
                            if nextStep then
                                if NeedsBreaking(nextStep.x, nextStep.y, true, cy) then
                                    PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false; _G.CurrentlyBreaking = Vector2.new(nextStep.x, nextStep.y)
                                    PlayerFist:FireServer(_G.CurrentlyBreaking); _G.CurrentStatus = "Status lock ["..nextStep.x..", "..nextStep.y.."] melakukan [BREAK MENUJU LOOT]"
                                else
                                    local targetWorldX = nextStep.x * TILE_SIZE; local tolerance = 1.2
                                    if nextStep.x == STATE.globalTargetLoot.x and nextStep.y == STATE.globalTargetLoot.y then targetWorldX = STATE.globalTargetLoot.pos.X; tolerance = 1.5 end
                                    local diffX = targetWorldX - root.Position.X
                                    if diffX > tolerance then PlayerMovement.MoveX = 1 elseif diffX < -tolerance then PlayerMovement.MoveX = -1 else
                                        PlayerMovement.MoveX = 0
                                        if targetWorldX == nextStep.x * TILE_SIZE then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                                    end
                                    PlayerMovement.Jumping = (nextStep.y > cy); _G.CurrentStatus = "Status lock ["..STATE.globalTargetLoot.x..", "..STATE.globalTargetLoot.y.."] melakukan [AMBIL LOOT]"
                                    if cx == nextStep.x and cy == nextStep.y and _G.PathNextStepIndex < #_G.CurrentSmartPath then _G.PathNextStepIndex = _G.PathNextStepIndex + 1 end
                                end
                            end
                        end
                    end
                else
                    if STATE.radarTotalDrops == 0 then
                        if STATE.isFactoryRunning then factoryShouldAdvance = true else TurnOffBot("WORLD CLEARED ATAU TARGET HABIS") end
                    else
                        PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false
                        _G.CurrentStatus = "STATUS: MEMASTIKAN AREA BERSIH..."
                    end
                    actedOnAction = true
                end
            end

            -- 7. AUTO FARM
            if not actedOnAction and STATE.autoFarm then
                if char and char:FindFirstChild("Humanoid") then
                    char.Humanoid.WalkSpeed = 55
                end

                if STATE.farmTargetBlock == "" then
                    if STATE.isFactoryRunning then factoryShouldAdvance = true else TurnOffBot("TARGET FARM KOSONG!") end
                    actedOnAction = true
                else
                    local seedSlot = GetInventorySlot(STATE.farmTargetBlock)

                    if STATE.botPhase == "PLANTING" and not seedSlot and #STATE.actionQueue > 0 then
                        STATE.actionQueue = {}
                        _G.CurrentSmartPath = nil
                    end

if #STATE.actionQueue == 0 or (STATE.botPhase == "WAITING" and os.time() >= (STATE.actionQueue[1].waitTime or 0)) then
                        STATE.actionQueue = BuildFarmQueue(cx, cy)
                    end

                    -- [TITAN PATCH: PABRIK LANJUT OTOMATIS SAAT SELESAI/MENUNGGU]
                    if STATE.isFactoryRunning and (STATE.botPhase == "WAITING" or #STATE.actionQueue == 0) then
                        factoryShouldAdvance = true
                        STATE.actionQueue = {}
                    elseif #STATE.actionQueue == 0 and not STATE.isFactoryRunning then
                        TurnOffBot("AUTO FARM SELESAI")
                    elseif #STATE.actionQueue > 0 then
                        local target = STATE.actionQueue[1]

                        if target.action == "FARM_LOOT" and (not target.inst or not target.inst.Parent) then
                            table.remove(STATE.actionQueue, 1)
                            actedOnAction = true
                            return 
                        end

                        local isAtTarget = false
                        if target.action == "WAIT" then
                            isAtTarget = cx == target.x and cy == target.y and math.abs((target.x * TILE_SIZE) - root.Position.X) < 1.0
                        else
                            isAtTarget = cx == target.x and cy == target.y and math.abs((target.x * TILE_SIZE) - root.Position.X) < 1.0
                        end
                        
                        if isAtTarget then
                            PlayerMovement.MoveX = 0
                            PlayerMovement.Jumping = false
                            
                            -- [TITAN PATCH: CLEAR CACHE PATHING AGAR ANTI-STUCK TIDAK PANIK]
                            _G.PathTargetKey = nil
                            _G.CurrentSmartPath = nil

                            if target.action == "PLANT" then
                                if CanPlantAt(cx, cy) and seedSlot then
                                    local pKey = cx.."_"..cy
                                    if not _G.PendingPlants[pKey] or os.clock() > _G.PendingPlants[pKey] then
                                        PlayerPlaceItem:FireServer(Vector2.new(cx, cy), seedSlot)
                                        _G.PendingPlants[pKey] = os.clock() + 0.001 
                                        local growDur = tonumber(STATE.customFarmTimer) or 30
                                        STATE.TreeTracker[pKey] = os.time() + growDur
                                    end
                                end
                                table.remove(STATE.actionQueue, 1)
                                _G.CurrentStatus = "STATUS: FARMING - MENANAM " .. string.upper(STATE.farmTargetBlock)

                            elseif target.action == "HARVEST" then
                                local tName = GetSafeName(WorldManager.GetTile(cx, cy, 1))
                                if tName:find("TREE") or tName:find("SAPLING") then
                                    if os.clock() - _G.LastFistTime >= 0.001 then 
                                        _G.CurrentlyBreaking = Vector2.new(cx, cy)
                                        PlayerFist:FireServer(_G.CurrentlyBreaking)
                                        _G.LastFistTime = os.clock()
                                    end
                                    _G.CurrentStatus = "STATUS: FARMING - MEMANEN POHON"
                                else
                                    STATE.TreeTracker[cx.."_"..cy] = nil
                                    _G.CurrentlyBreaking = nil
                                    table.remove(STATE.actionQueue, 1)
                                end

                            elseif target.action == "FARM_LOOT" then
                                _G.CurrentStatus = "STATUS: FARMING - SWEEPING LOOT ("..target.x..","..target.y..")"

                            elseif target.action == "WAIT" then
                                PlayerMovement.MoveX = 0
                                PlayerMovement.Jumping = false
                                local sisaDetik = math.max(0, target.waitTime - os.time())
                                _G.CurrentStatus = "STATUS: FARMING - MENUNGGU TUMBUH (" .. FormatTimeID(sisaDetik) .. ")"
                            end
                        else
                            local targetKey = "FARM_MOVE_" .. target.x .. "_" .. target.y
                            if _G.PathTargetKey ~= targetKey or tick() - STATE.lastPathCalc > 0.5 or not _G.CurrentSmartPath then
                                _G.CurrentSmartPath = FindSmartPath(cx, cy, target.x, target.y, "AIR_ONLY")
                                _G.PathNextStepIndex = 1; _G.PathTargetKey = targetKey; STATE.lastPathCalc = tick()
                            end

                            if _G.CurrentSmartPath then
                                local nextStep = _G.CurrentSmartPath[_G.PathNextStepIndex]
                                if not nextStep and cx == target.x and cy == target.y then nextStep = {x = target.x, y = target.y} end

                                if nextStep then
                                    local targetWorldX = nextStep.x * TILE_SIZE; local diffX = targetWorldX - root.Position.X
                                    if diffX > 1.2 then PlayerMovement.MoveX = 1 elseif diffX < -1.2 then PlayerMovement.MoveX = -1 else
                                        PlayerMovement.MoveX = 0
                                        if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                                    end
                                    PlayerMovement.Jumping = (nextStep.y > cy); 
                                    
                                    if target.action == "WAIT" then _G.CurrentStatus = "STATUS: MENUJU TITIK AWAL MENGHINDARI BLOK..." else _G.CurrentStatus = "STATUS: MENUJU TITIK FARM ["..target.x..", "..target.y.."]" end
                                    
                                    if cx == nextStep.x and cy == nextStep.y and _G.PathNextStepIndex < #_G.CurrentSmartPath then _G.PathNextStepIndex = _G.PathNextStepIndex + 1 end
                                end
                            else
                                local targetWorldX = target.x * TILE_SIZE
                                local diffX = targetWorldX - root.Position.X
                                if diffX > 1.2 then PlayerMovement.MoveX = 1 elseif diffX < -1.2 then PlayerMovement.MoveX = -1 else 
                                    PlayerMovement.MoveX = 0 
                                    if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                                end
                                PlayerMovement.Jumping = (target.y > cy)
                                _G.CurrentStatus = "STATUS: FORCED MOVE KE TITIK FARM"
                            end
                        end
                    end
                    actedOnAction = true
                end
            end

            -- 8. AUTO PLACE
            if not actedOnAction and STATE.autoPlace then
                if STATE.placeTargetBlock == "" then
                    if STATE.isFactoryRunning then factoryShouldAdvance = true else TurnOffBot("TARGET PLACE KOSONG!") end
                    actedOnAction = true
                else
                    local itemSlot = GetInventorySlot(STATE.placeTargetBlock)
                    if not itemSlot then
                        if STATE.isFactoryRunning then factoryShouldAdvance = true else TurnOffBot("OUT OF BLOCKS FOR PLACE") end
                        actedOnAction = true
                    else
                        if not STATE.placeQueue or #STATE.placeQueue == 0 then
                            STATE.placeQueue = BuildPlaceQueue(cx, cy)
                        end

                        if #STATE.placeQueue > 0 then
                            local target = STATE.placeQueue[1]
                            local targetY = target.y
                            local destY = targetY + 1

                            local targetWorldY = destY * TILE_SIZE
                            if math.abs(root.Position.Y - targetWorldY) < (TILE_SIZE * 0.8) then
                                for xOffset = -2, 2 do
                                    local checkX = cx + xOffset
                                    if checkX >= 1 and checkX <= 99 then
                                        local tName = GetSafeName(WorldManager.GetTile(checkX, targetY, 1))
                                        if tName == "AIR" and not IsProtected(checkX, targetY) then
                                            local pKey = "AURA_"..checkX.."_"..targetY
                                            if not _G.PendingPlants[pKey] or os.clock() > _G.PendingPlants[pKey] then
                                                PlayerPlaceItem:FireServer(Vector2.new(checkX, targetY), itemSlot)
                                                _G.PendingPlants[pKey] = os.clock() + 0.1
                                            end
                                        end
                                    end
                                end
                            end

                            local destX = target.x
                            local tName = GetSafeName(WorldManager.GetTile(target.x, target.y, 1))

                            if tName ~= "AIR" then
                                table.remove(STATE.placeQueue, 1)
                            else
                                local botAtCorrectHeight = math.abs(root.Position.Y - (destY * TILE_SIZE)) < (TILE_SIZE * 0.8)

                                if botAtCorrectHeight then
                                    if math.abs((destX * TILE_SIZE) - root.Position.X) > 0.4 then
                                        PlayerMovement.MoveX = (destX > cx) and 1 or (destX < cx and -1 or 0)
                                    else
                                        PlayerMovement.MoveX = 0
                                    end
                                    PlayerMovement.Jumping = false
                                    _G.CurrentStatus = "STATUS: AUTO PLACE ROW Y: " .. targetY
                                else
                                    if cx == target.x and cy == target.y then
                                        PlayerMovement.Jumping = true
                                        PlayerMovement.MoveX = 0
                                    else
                                        local targetKey = "PLACE_MOVE_" .. target.x .. "_" .. destY
                                        if _G.PathTargetKey ~= targetKey or tick() - STATE.lastPathCalc > 0.5 or not _G.CurrentSmartPath then
                                            _G.CurrentSmartPath = FindSmartPath(cx, cy, target.x, destY, "BREAK")
                                            _G.PathNextStepIndex = 1; _G.PathTargetKey = targetKey; STATE.lastPathCalc = tick()
                                        end

                                        if _G.CurrentSmartPath then
                                            local nextStep = _G.CurrentSmartPath[_G.PathNextStepIndex]
                                            if not nextStep and cx == target.x and cy == destY then nextStep = {x = target.x, y = destY} end

                                            if nextStep then
                                                if NeedsBreaking(nextStep.x, nextStep.y, true, cy) then
                                                    PlayerMovement.MoveX = 0; PlayerMovement.Jumping = false; _G.CurrentlyBreaking = Vector2.new(nextStep.x, nextStep.y)
                                                    PlayerFist:FireServer(_G.CurrentlyBreaking); _G.CurrentStatus = "STATUS: BREAKING UNTUK PLACE KE ["..target.x..", "..destY.."]"
                                                else
                                                    local targetWorldX = nextStep.x * TILE_SIZE; local diffX = targetWorldX - root.Position.X
                                                    if diffX > 1.2 then PlayerMovement.MoveX = 1 elseif diffX < -1.2 then PlayerMovement.MoveX = -1 else
                                                        PlayerMovement.MoveX = 0
                                                        if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                                                    end
                                                    PlayerMovement.Jumping = (nextStep.y > cy); _G.CurrentStatus = "STATUS: MENUJU POSISI PLACE ["..target.x..", "..destY.."]"
                                                    if cx == nextStep.x and cy == nextStep.y and _G.PathNextStepIndex < #_G.CurrentSmartPath then _G.PathNextStepIndex = _G.PathNextStepIndex + 1 end
                                                end
                                            end
                                        else
                                            local targetWorldX = target.x * TILE_SIZE
                                            local diffX = targetWorldX - root.Position.X
                                            if diffX > 1.2 then PlayerMovement.MoveX = 1 elseif diffX < -1.2 then PlayerMovement.MoveX = -1 else
                                                PlayerMovement.MoveX = 0
                                                if math.abs(root.Position.X - targetWorldX) > 0.01 then root.CFrame = CFrame.new(targetWorldX, root.Position.Y, root.Position.Z); root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, root.AssemblyLinearVelocity.Z) end
                                            end
                                            PlayerMovement.Jumping = (destY > cy)
                                            _G.CurrentStatus = "STATUS: FORCED MOVE KE POSISI PLACE"
                                        end
                                    end
                                end
                            end
                        else
                            if STATE.isFactoryRunning then factoryShouldAdvance = true else TurnOffBot("AUTO PLACE SELESAI") end
                        end
                        actedOnAction = true
                    end
                end
            end
        end

        -- ==========================================
        -- FACTORY POST-EXECUTION EVALUATION
        -- ==========================================
        if STATE.isFactoryRunning then
            if _G.CurrentStatus:find("STUCK") then STATE.factoryStuckCounter = STATE.factoryStuckCounter + 1 else STATE.factoryStuckCounter = 0 end
            if STATE.factoryStuckCounter > 150 then factoryShouldAdvance = true; STATE.factoryStuckCounter = 0 end 

            if factoryShouldAdvance then
                STATE.currentFactoryIndex = STATE.currentFactoryIndex + 1; STATE.activeFactoryTask = nil
                if STATE.currentFactoryIndex > #STATE.factoryQueue then TurnOffBot("PABRIK SELESAI") end
            end
            
            if STATE.isFactoryRunning then
                if not _G.CurrentStatus:find("PABRIK MENUNGGU") and not _G.CurrentStatus:find("MENUNGGU SISA TUGAS") then
                    UI.GlobalStatus.Text = " [FACTORY: " .. (STATE.factoryQueue[STATE.currentFactoryIndex] or "") .. "] " .. _G.CurrentStatus
                else
                    UI.GlobalStatus.Text = " " .. _G.CurrentStatus
                end
            end
        else
            if not _G.CurrentStatus:find("STOPPED") and not _G.CurrentStatus:find("DIRESET") then
                UI.GlobalStatus.Text = " " .. _G.CurrentStatus
            end
        end
    end)

    print("TITAN ENTERPRISE V983 (SMART FRAME PATH & SOLID Y+1) LOADED!")
end

-- ==============================================================================
-- ENTERPRISE GUARD (PCALL WRAPPER)
-- ==============================================================================
local success, result = pcall(InitTitanEnterprise)

if not success then
    warn("============= TITAN ENTERPRISE FATAL ERROR =============")
    warn("ERROR DETAILS: ", result)
    warn("Pastikan environment eksekutor stabil atau tunggu karakter sepenuhnya dimuat!")
    warn("========================================================")
end