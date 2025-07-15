if not ActionRecorder then ActionRecorder = {} end

local PANEL = {}

function PANEL:Init()
    self:SetSize(500, 500)
    self:SetTitle("Custom Easing Editor")
    self:MakePopup()

    self.Points = ActionRecorder.CustomEasingPoints or {
        {x = 0, y = 0},
        {x = 1, y = 1}
    }

    self.Canvas = self:Add("DPanel")
    self.Canvas:SetPos(10, 30)
    self.Canvas:SetSize(480, 420)
    self.Canvas.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(50, 50, 50))

        -- Draw grid
        for i = 1, 9 do
            local x = i * w / 10
            local y = i * h / 10
            surface.SetDrawColor(Color(70, 70, 70))
            surface.DrawLine(x, 0, x, h)
            surface.DrawLine(0, y, w, y)
        end

        -- Draw lines between points
        surface.SetDrawColor(Color(255, 255, 255))
        for i = 1, #self.Points - 1 do
            local p1 = self.Points[i]
            local p2 = self.Points[i+1]
            surface.DrawLine(p1.x * w, h - p1.y * h, p2.x * w, h - p2.y * h)
        end

        -- Draw points
        for i, p in ipairs(self.Points) do
            surface.SetDrawColor(Color(255, 0, 0))
            surface.DrawRect(p.x * w - 3, h - p.y * h - 3, 7, 7)
        end
    end

    self.Canvas.OnMousePressed = function(s, mc)
        local x, y = s:CursorPos()
        local w, h = s:GetSize()
        x = x / w
        y = 1 - y / h

        if mc == MOUSE_LEFT then
            local selected_point = nil
            for i, p in ipairs(self.Points) do
                if math.abs(p.x - x) < 0.02 and math.abs(p.y - y) < 0.02 then
                    selected_point = i
                    break
                end
            end

            if selected_point then
                self.SelectedPoint = selected_point
            else
                table.insert(self.Points, {x = x, y = y})
                table.sort(self.Points, function(a, b) return a.x < b.x end)
            end
        elseif mc == MOUSE_RIGHT then
            local selected_point = nil
            for i, p in ipairs(self.Points) do
                if math.abs(p.x - x) < 0.02 and math.abs(p.y - y) < 0.02 then
                    selected_point = i
                    break
                end
            end

            if selected_point and #self.Points > 2 then
                table.remove(self.Points, selected_point)
            end
        end
    end

    self.Canvas.OnMouseReleased = function(s, mc)
        self.SelectedPoint = nil
    end

    self.Canvas.Think = function(s)
        if self.SelectedPoint and input.IsMouseDown(MOUSE_LEFT) then
            local x, y = s:CursorPos()
            local w, h = s:GetSize()
            x = math.Clamp(x / w, 0, 1)
            y = math.Clamp(1 - y / h, 0, 1)

            local point = self.Points[self.SelectedPoint]
            point.x = x
            point.y = y

            table.sort(self.Points, function(a, b) return a.x < b.x end)
        end
    end

    self.SaveButton = self:Add("DButton")
    self.SaveButton:SetText("Save")
    self.SaveButton:SetPos(10, 460)
    self.SaveButton:SetSize(100, 30)
    self.SaveButton.DoClick = function()
        ActionRecorder.CustomEasingPoints = self.Points
        self:Close()
    end

    self.ResetButton = self:Add("DButton")
    self.ResetButton:SetText("Reset")
    self.ResetButton:SetPos(120, 460)
    self.ResetButton:SetSize(100, 30)
    self.ResetButton.DoClick = function()
        self.Points = {
            {x = 0, y = 0},
            {x = 1, y = 1}
        }
    end
end

vgui.Register("ActionRecorderGraphEditor", PANEL, "DFrame")
