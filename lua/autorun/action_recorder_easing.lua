if not ActionRecorder then ActionRecorder = {} end
ActionRecorder.EasingFunctions = {
    ["None"] = function(t) return 1 end,
    ["Linear"] = function(t) return t end,
    ["EaseInSine"] = function(t) return 1 - math.cos((t * math.pi) / 2) end,
    ["EaseOutSine"] = function(t) return math.sin((t * math.pi) / 2) end,
    ["EaseInOutSine"] = function(t) return -(math.cos(math.pi * t) - 1) / 2 end,
    ["EaseInQuad"] = function(t) return t * t end,
    ["EaseOutQuad"] = function(t) return 1 - (1 - t) * (1 - t) end,
    ["EaseInOutQuad"] = function(t) return t < 0.5 and 2 * t * t or 1 - math.pow(-2 * t + 2, 2) / 2 end,
    ["EaseInCubic"] = function(t) return t * t * t end,
    ["EaseOutCubic"] = function(t) return 1 - math.pow(1 - t, 3) end,
    ["EaseInOutCubic"] = function(t) return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2 end,
    ["EaseInQuart"] = function(t) return t * t * t * t end,
    ["EaseOutQuart"] = function(t) return 1 - math.pow(1 - t, 4) end,
    ["EaseInOutQuart"] = function(t) return t < 0.5 and 8 * t * t * t * t or 1 - math.pow(-2 * t + 2, 4) / 2 end,
    ["EaseInQuint"] = function(t) return t * t * t * t * t end,
    ["EaseOutQuint"] = function(t) return 1 - math.pow(1 - t, 5) end,
    ["EaseInOutQuint"] = function(t) return t < 0.5 and 16 * t * t * t * t * t or 1 - math.pow(-2 * t + 2, 5) / 2 end,
    ["EaseInExpo"] = function(t) return t == 0 and 0 or math.pow(2, 10 * t - 10) end,
    ["EaseOutExpo"] = function(t) return t == 1 and 1 or 1 - math.pow(2, -10 * t) end,
    ["EaseInOutExpo"] = function(t)
        return t == 0 and 0 or t == 1 and 1 or t < 0.5 and math.pow(2, 20 * t - 10) / 2 or (2 - math.pow(2, -20 * t + 10)) / 2
    end,
    ["EaseInCirc"] = function(t) return 1 - math.sqrt(1 - math.pow(t, 2)) end,
    ["EaseOutCirc"] = function(t) return math.sqrt(1 - math.pow(t - 1, 2)) end,
    ["EaseInOutCirc"] = function(t)
        return t < 0.5 and (1 - math.sqrt(1 - math.pow(2 * t, 2))) / 2 or (math.sqrt(1 - math.pow(-2 * t + 2, 2)) + 1) / 2
    end,
    ["EaseOutBack"] = function(t)
        local c1 = 1.70158
        local c3 = c1 + 1
        return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
    end,
    ["EaseInOutBack"] = function(t)
        local c1 = 1.70158
        local c2 = c1 * 1.525
        return t < 0.5 and (math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2 or (math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
    end,
    ["EaseOutElastic"] = function(t)
        local c4 = (2 * math.pi) / 3
        return t == 0 and 0 or t == 1 and 1 or math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
    end,
    ["EaseInOutElastic"] = function(t)
        local c5 = (2 * math.pi) / 4.5
        return t == 0 and 0 or t == 1 and 1 or t < 0.5 and -(math.pow(2, 20 * t - 10) * math.sin((20 * t - 11.125) * c5)) / 2 or (math.pow(2, -20 * t + 10) * math.sin((20 * t - 11.125) * c5)) / 2 + 1
    end,
    ["EaseInBounce"] = function(t) return 1 - ActionRecorder.EasingFunctions.EaseOutBounce(1 - t) end,
    ["EaseOutBounce"] = function(t)
        local n1 = 7.5625
        local d1 = 2.75
        if t < 1 / d1 then
            return n1 * t * t
        elseif t < 2 / d1 then
            t = t - 1.5 / d1
            return n1 * t * t + 0.75
        elseif t < 2.5 / d1 then
            t = t - 2.25 / d1
            return n1 * t * t + 0.9375
        else
            t = t - 2.625 / d1
            return n1 * t * t + 0.984375
        end
    end,
    ["EaseInOutBounce"] = function(t)
        return t < 0.5 and (1 - ActionRecorder.EasingFunctions.EaseOutBounce(1 - 2 * t)) / 2 or (1 + ActionRecorder.EasingFunctions.EaseOutBounce(2 * t - 1)) / 2
    end,
    ["SawWave"] = function(t) return t end,
    ["TriangleWave"] = function(t) return math.abs((t * 2) - 1) end,
    ["SquareWave"] = function(t) return t >= 0.5 and 1 or 0 end,
    ["Custom"] = function(t)
        if not ActionRecorder.CustomEasingPoints then return t end
        local points = ActionRecorder.CustomEasingPoints
        if #points < 2 then return t end

        if t <= points[1].x then return points[1].y end
        if t >= points[#points].x then return points[#points].y end

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
        return Lerp(tt, p1.y, p2.y)
    end
}
