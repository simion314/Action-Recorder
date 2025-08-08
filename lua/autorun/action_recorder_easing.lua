if not ActionRecorder then ActionRecorder = {} end

local function applyModifiers(val, amp, freq, inv, offset)
    val = val * amp
    val = val + offset
    if inv then
        val = 1 - val
    end
    return val
end

ActionRecorder.EasingFunctions = {
    ["None"] = function(t, amp, freq, inv, offset) 
        return applyModifiers(1, amp, freq, inv, offset) 
    end,
    ["Linear"] = function(t, amp, freq, inv, offset) 
        return applyModifiers(t, amp, freq, inv, offset) 
    end,
    ["EaseInOutSine"] = function(t, amp, freq, inv, offset) 
        return applyModifiers(-(math.cos(math.pi * t) - 1) / 2, amp, freq, inv, offset) 
    end,
    ["EaseInOutQuad"] = function(t, amp, freq, inv, offset) 
        return applyModifiers(t < 0.5 and 2 * t * t or 1 - math.pow(-2 * t + 2, 2) / 2, amp, freq, inv, offset) 
    end,
    ["EaseInOutCubic"] = function(t, amp, freq, inv, offset) 
        return applyModifiers(t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2, amp, freq, inv, offset) 
    end,
    ["EaseInOutExpo"] = function(t, amp, freq, inv, offset)
        return applyModifiers(t == 0 and 0 or t == 1 and 1 or t < 0.5 and math.pow(2, 20 * t - 10) / 2 or (2 - math.pow(2, -20 * t + 10)) / 2, amp, freq, inv, offset)
    end,
    ["EaseOutBounce"] = function(t, amp, freq, inv, offset)
        local n1 = 7.5625
        local d1 = 2.75
        if t < 1 / d1 then
            return applyModifiers(n1 * t * t, amp, freq, inv, offset)
        elseif t < 2 / d1 then
            t = t - (1.5 / d1)
            return applyModifiers(n1 * t * t + 0.75, amp, freq, inv, offset)
        elseif t < 2.5 / d1 then
            t = t - (2.25 / d1)
            return applyModifiers(n1 * t * t + 0.9375, amp, freq, inv, offset)
        else
            t = t - (2.625 / d1)
            return applyModifiers(n1 * t * t + 0.984375, amp, freq, inv, offset)
        end
    end,
    ["SawWave"] = function(t, amp, freq, inv, offset) 
        return applyModifiers(t, amp, freq, inv, offset) 
    end,
    ["TriangleWave"] = function(t, amp, freq, inv, offset) 
        return applyModifiers(math.abs((t * 2) - 1), amp, freq, inv, offset) 
    end,
    ["SquareWave"] = function(t, amp, freq, inv, offset) 
        return applyModifiers(t >= 0.5 and 1 or 0, amp, freq, inv, offset) 
    end,
    ["Custom"] = function(t, amp, freq, inv, offset)
        if not ActionRecorder.CustomEasingPoints then return t end
        local points = ActionRecorder.CustomEasingPoints
        if #points < 2 then return t end

        if t <= points[1].x then return applyModifiers(points[1].y, amp, freq, inv, offset) end
        if t >= points[#points].x then return applyModifiers(points[#points].y, amp, freq, inv, offset) end

        local p1, p2
        for i = 1, #points - 1 do
            if t >= points[i].x and t <= points[i+1].x then
                p1 = points[i]
                p2 = points[i+1]
                break
            end
        end

        if not p1 or not p2 then return t end

        local tt = (t - p1.x) / (p2.x - p1.x)
        local ft = tt * math.pi
        local f = (1 - math.cos(ft)) * 0.5
        return applyModifiers(p1.y * (1 - f) + p2.y * f, amp, freq, inv, offset)
    end
}