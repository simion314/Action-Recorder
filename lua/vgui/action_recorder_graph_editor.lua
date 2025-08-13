if not ActionRecorder then ActionRecorder = {} end

local PANEL = {}

function PANEL:Init()
    self:SetSize(800, 600)
    self:SetTitle("Custom Easing Editor")
    self:MakePopup()
    self:SetDeleteOnClose(true)

    self.Points = ActionRecorder.CustomEasingPoints or {
        {x = 0, y = 0},
        {x = 1, y = 1}
    }

    self.Zoom = 1.0
    self.PanX = 0
    self.PanY = 0

    self.Canvas = self:Add("DPanel")
    self.Canvas:Dock(FILL)
    self.Canvas:SetBackgroundColor(Color(50, 50, 50))

    self.Canvas.Paint = function(s, w, h)
        -- Draw grid
        local grid_size = 50 * self.Zoom
        local offset_x = self.PanX * self.Zoom
        local offset_y = self.PanY * self.Zoom

        surface.SetDrawColor(Color(70, 70, 70, 150))
        for x = math.fmod(offset_x, grid_size) - grid_size, w, grid_size do
            surface.DrawLine(x, 0, x, h)
        end
        for y = math.fmod(offset_y, grid_size) - grid_size, h, grid_size do
            surface.DrawLine(0, y, w, y)
        end

        surface.SetDrawColor(Color(90, 90, 90, 200))
        local major_grid_size = 250 * self.Zoom
        for x = math.fmod(offset_x, major_grid_size) - major_grid_size, w, major_grid_size do
            surface.DrawLine(x, 0, x, h)
        end
        for y = math.fmod(offset_y, major_grid_size) - major_grid_size, h, major_grid_size do
            surface.DrawLine(0, y, w, y)
        end

        -- Transform points for drawing
        local transformed_points = {}
        for i, p in ipairs(self.Points) do
            local tx = (p.x * w * self.Zoom) + offset_x
            local ty = h - ((p.y * h * self.Zoom) + offset_y)
            table.insert(transformed_points, {x = tx, y = ty})
        end

        -- Draw lines between points
        surface.SetDrawColor(Color(255, 255, 255))
        for i = 1, #transformed_points - 1 do
            local p1 = transformed_points[i]
            local p2 = transformed_points[i+1]
            surface.DrawLine(p1.x, p1.y, p2.x, p2.y)
        end

        -- Draw points
        for i, p in ipairs(transformed_points) do
            local point_color = Color(255, 0, 0)
            if self.SelectedPoint == i then
                point_color = Color(0, 255, 0) -- Highlight selected point
            end
            surface.SetDrawColor(point_color)
            surface.DrawRect(p.x - 4, p.y - 4, 8, 8)
        end
    end

    self.Canvas.OnMouseWheeled = function(s, delta)
        local cursor_x, cursor_y = s:CursorPos()
        local old_zoom = self.Zoom

        if delta > 0 then
            self.Zoom = self.Zoom * 1.1
        else
            self.Zoom = self.Zoom / 1.1
        end
        self.Zoom = math.Clamp(self.Zoom, 0.1, 10.0)

        -- Adjust pan to zoom towards cursor
        self.PanX = cursor_x - ((cursor_x - self.PanX) / old_zoom) * self.Zoom
        self.PanY = cursor_y - ((cursor_y - self.PanY) / old_zoom) * self.Zoom
        return true
    end

    self.Canvas.OnMousePressed = function(s, mc)
        local cursor_x, cursor_y = s:CursorPos()
        local w, h = s:GetSize()

        local graph_x = (cursor_x - self.PanX) / (w * self.Zoom)
        local graph_y = 1 - ((cursor_y - self.PanY) / (h * self.Zoom))

        if mc == MOUSE_LEFT then
            self.DraggingPan = true
            self.LastMouseX, self.LastMouseY = gui.MouseX(), gui.MouseY()

            local selected_point = nil
            for i, p in ipairs(self.Points) do
                local tx = (p.x * w * self.Zoom) + self.PanX
                local ty = h - ((p.y * h * self.Zoom) + self.PanY)
                if math.abs(tx - cursor_x) < 8 and math.abs(ty - cursor_y) < 8 then
                    selected_point = i
                    break
                end
            end

            if selected_point then
                self.SelectedPoint = selected_point
                self.DraggingPoint = true
            else
                -- Add new point
                table.insert(self.Points, {x = graph_x, y = graph_y})
                table.sort(self.Points, function(a, b) return a.x < b.x end)
            end
        elseif mc == MOUSE_RIGHT then
            local selected_point = nil
            for i, p in ipairs(self.Points) do
                local tx = (p.x * w * self.Zoom) + self.PanX
                local ty = h - ((p.y * h * self.Zoom) + self.PanY)
                if math.abs(tx - cursor_x) < 8 and math.abs(ty - cursor_y) < 8 then
                    selected_point = i
                    break
                end
            end

            if selected_point and #self.Points > 2 then
                table.remove(self.Points, selected_point)
                self.SelectedPoint = nil
            end
        end
    end

    self.Canvas.OnMouseReleased = function(s, mc)
        self.SelectedPoint = nil
        self.DraggingPoint = false
        self.DraggingPan = false
    end

    self.Canvas.OnMouseDragged = function(s, mx, my)
        if self.DraggingPan and input.IsMouseDown(MOUSE_LEFT) then
            local dx = mx - self.LastMouseX
            local dy = my - self.LastMouseY
            self.PanX = self.PanX + dx
            self.PanY = self.PanY + dy
            self.LastMouseX, self.LastMouseY = mx, my
        end
    end

    self.Canvas.Think = function(s)
        if self.DraggingPoint and input.IsMouseDown(MOUSE_LEFT) then
            local x, y = s:CursorPos()
            local w, h = s:GetSize()

            local graph_x = (x - self.PanX) / (w * self.Zoom)
            local graph_y = 1 - ((y - self.PanY) / (h * self.Zoom))

            graph_x = math.Clamp(graph_x, 0, 1)
            graph_y = math.Clamp(graph_y, 0, 1)

            local point = self.Points[self.SelectedPoint]
            point.x = graph_x
            point.y = graph_y

            table.sort(self.Points, function(a, b) return a.x < b.x end)
        end
    end

    local ButtonPanel = self:Add("DPanel")
    ButtonPanel:Dock(BOTTOM)
    ButtonPanel:SetTall(40)
    ButtonPanel:SetBackgroundColor(Color(60, 60, 60))

    self.SaveButton = ButtonPanel:Add("DButton")
    self.SaveButton:SetText("Save")
    self.SaveButton:SetPos(10, 5)
    self.SaveButton:SetSize(100, 30)
    self.SaveButton.DoClick = function()
        ActionRecorder.CustomEasingPoints = self.Points
        self:Close()
    end

    self.ResetButton = ButtonPanel:Add("DButton")
    self.ResetButton:SetText("Reset")
    self.ResetButton:SetPos(120, 5)
    self.ResetButton:SetSize(100, 30)
    self.ResetButton.DoClick = function()
        self.Points = {
            {x = 0, y = 0},
            {x = 1, y = 1}
        }
        self.Zoom = 1.0
        self.PanX = 0
        self.PanY = 0
    end

    self.CloseButton = ButtonPanel:Add("DButton")
    self.CloseButton:SetText("Close")
    self.CloseButton:SetPos(230, 5)
    self.CloseButton:SetSize(100, 30)
    self.CloseButton.DoClick = function()
        self:Close()
    end
end

vgui.Register("ActionRecorderGraphEditor", PANEL, "DFrame")
