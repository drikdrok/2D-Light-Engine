math.randomseed(os.time())
local shader = [[
	struct Light {
		vec2 position;
		vec3 color; 
		float intensity;
	};

	extern Light light;

	extern vec2 screenSize;

	extern Image lightMap;
	
	vec4 effect(vec4 color, Image image, vec2 uvs, vec2 screenCoords){

		vec4 pixel = Texel(image, uvs);

		vec2 normScreen = screenCoords / screenSize;
		vec2 normPos = light.position / screenSize;
		
		float distance = length(normPos - normScreen) * light.intensity;
		
		float brightness = 1.0 / (1.0 + 0.1 * distance + 0.032 * (distance * distance));
		
		vec3 lightColor = light.color * brightness;

		lightColor = clamp(lightColor, 0.0, 1.0);
		
		vec4 lightPixel = Texel(lightMap, normScreen);
		
		if (lightPixel[0] > 0) { // Pixel is lit by light
			return pixel * vec4(lightColor, 1);
		}else{
			return vec4(0,0,0,0);
		}
	}

]]



function love.load()
	shader = love.graphics.newShader(shader)
	img = love.graphics.newImage("img.png")

	edges = {
		{x = 0, y = 0, endX = 800, endY = 0},
		{x = 0, y = 0, endX = 0, endY = 600},
		{x = 0, y = 600, endX = 800, endY = 600},
		{x = 800, y = 0, endX = 800, endY = 600}
	}

	visibillityPolygon = {}

	mouseDown = false

	
	lightMaps = {}
	
	showRays = false
	showRayCanvas = love.graphics.newCanvas(800, 600)
	
	lights = {}
	newLight(100, 100, {1, 1, 1}, 32)

end

function love.update(dt)
	local mouseX, mouseY = love.mouse.getPosition()

	if love.mouse.isDown(1) then 
		if mouseDown then 
			--Expand edges of currently expanding square
			edges[#edges-3].endX = edges[#edges-3].endX + 1
		
			edges[#edges-2].endY = edges[#edges-2].endY + 1
			
			edges[#edges-1].x = edges[#edges-1].x + 1
			edges[#edges-1].endX = edges[#edges-1].endX + 1
			edges[#edges-1].endY = edges[#edges-1].endY + 1

			edges[#edges].y = edges[#edges].y + 1
			edges[#edges].endX = edges[#edges].endX + 1
			edges[#edges].endY = edges[#edges].endY + 1
		else
			mouseDown = true
			table.insert(edges, {x = mouseX + 16, y = mouseY, endX = mouseX + 32, endY = mouseY}) 
			table.insert(edges, {x = mouseX + 16, y = mouseY, endX = mouseX + 16, endY = mouseY + 16}) 
			table.insert(edges, {x = mouseX + 32, y = mouseY, endX = mouseX + 32, endY = mouseY + 16}) 
			table.insert(edges, {x = mouseX + 16, y = mouseY + 16, endX = mouseX + 32, endY = mouseY + 16}) 
		end
	else
		mouseDown = false
	end

	lights[1][1] =  {love.mouse.getX(), love.mouse.getY()}

	generateLightMap()
end

function love.draw()
	local worldCanvas = love.graphics.newCanvas(800, 600)
	love.graphics.setCanvas(worldCanvas) -- Draw everything in the world
	
	love.graphics.setColor(1,1,1)
	love.graphics.rectangle("fill", 0, 0, 800, 600)
	love.graphics.setColor(1,1,1)

	
	love.graphics.draw(img, 500, 200)

	love.graphics.setCanvas()


	
	--Apply light shader for every light and combine images additively
	love.graphics.setBlendMode("add")
	love.graphics.setShader(shader)
	shader:send("screenSize", {love.graphics.getWidth(), love.graphics.getHeight()})
	for i, light in pairs(lights) do

		shader:send("lightMap", lightMaps[i])
		
		shader:send("light.position", light[1])
		shader:send("light.color", light[2])
		shader:send("light.intensity", light[3])

		love.graphics.draw(worldCanvas)

	end
	love.graphics.setShader()

	if showRays then 
		love.graphics.draw(showRayCanvas)
	end
	
	
	love.graphics.setBlendMode("alpha")


	--Text
	love.graphics.setColor(1,1,1)
	love.graphics.print("FPS: "..love.timer.getFPS(), 730)
	love.graphics.print("F1 To toggle rays", 0, 0)
	love.graphics.print("Right click to place light", 0, 15)
	love.graphics.print("Left click to place box", 0, 30)
	love.graphics.print("R to reset", 0, 45)
	
end

function love.keypressed(key)
	if key == "escape" then 
		love.event.quit()
	elseif key == "f1" then 
		showRays = not showRays 
	elseif key == "r" then 
		edges = {
			{x = 0, y = 0, endX = 800, endY = 0},
			{x = 0, y = 0, endX = 0, endY = 600},
			{x = 0, y = 600, endX = 800, endY = 600},
			{x = 800, y = 0, endX = 800, endY = 600}
		}

	lights = {}
	newLight(100, 100, {1, 1, 1}, 32)

	end	
end

function love.mousepressed(x, y, button)
	if button == 2 then 
		newLight(x, y, {math.random(0, 1), math.random(0, 1), math.random(0, 1), }, 32)
	end
end

function generateLightMap()
	for i,v in pairs(lights) do
		love.graphics.setCanvas(lightMaps[i])
		love.graphics.clear()
		calculateVisibillityPolygon(v[1][1], v[1][2])


		love.graphics.setColor(1,0,0, 1)
		if #visibillityPolygon > 0 then 
			for i = 1, #visibillityPolygon-1 do
				love.graphics.polygon("fill", v[1][1], v[1][2], visibillityPolygon[i][1], visibillityPolygon[i][2], visibillityPolygon[i+1][1], visibillityPolygon[i+1][2])
			end
			love.graphics.polygon("fill", v[1][1], v[1][2], visibillityPolygon[#visibillityPolygon][1], visibillityPolygon[#visibillityPolygon][2], visibillityPolygon[1][1], visibillityPolygon[1][2])
		end
		love.graphics.setCanvas()


		if showRays and i == 1 then -- Show the rays being cast from the mouse light
			local mouseX, mouseY = love.mouse.getPosition()
			love.graphics.setCanvas(showRayCanvas)
				love.graphics.clear()
				love.graphics.setColor(1,1,1)
				for i,v in pairs(visibillityPolygon) do
					love.graphics.line(mouseX, mouseY, v[1], v[2])
				end
			
				for i,v in pairs(edges) do
					love.graphics.circle("fill", v.x, v.y, 3)
					love.graphics.circle("fill", v.endX, v.endY, 3)
				end
				for i,v in pairs(visibillityPolygon) do
					love.graphics.circle("fill", v[1], v[2], 3)
					love.graphics.circle("fill", v[1], v[2], 3)
				end
			love.graphics.setCanvas()
		end
	end
end


function calculateVisibillityPolygon(sourceX, sourceY)
	visibillityPolygon = {}

	for i, edge1 in pairs(edges) do -- Loop through every edge
			for j = 0, 2 do 
				local rayVectorX = edge1.x - sourceX -- Target either start or end point of edge
				local rayVectorY = edge1.y - sourceY
				if j == 1 then 
					 rayVectorX = edge1.endX - sourceX
					 rayVectorY = edge1.endY - sourceY
				end

				local baseAngle = math.atan2(rayVectorY, rayVectorX);

				local angle = 0
				for k = 0, 3 do -- Cast 3 rays with slightly different angles. This is so rays can go past edges
					if k == 0 then 
						angle = baseAngle - 0.0001 
					elseif k == 1 then 
						angle = baseAngle 		   
					elseif k == 2 then 
						angle = baseAngle + 0.0001 
					end

					rayVectorX = math.cos(angle)
					rayVectorY = math.sin(angle)

					local closest_t1 = 99999999
					local closestPointX = 0
					local closestPointY = 0
					local closestAngle = 0
					local isValid = false

					for l, edge2 in pairs(edges) do
						local segmentVectorX = edge2.endX - edge2.x
						local segmentVectorY = edge2.endY - edge2.y

						if math.abs(segmentVectorX - rayVectorX) > 0.0 and math.abs(segmentVectorY - rayVectorY) > 0.0 then -- Make sure vectors are not parralel
							
							local t2 = (rayVectorX * (edge2.y - sourceY) + (rayVectorY * (sourceX - edge2.x))) / (segmentVectorX * rayVectorY - segmentVectorY * rayVectorX)
							
							local t1 = (edge2.x + segmentVectorX * t2 - sourceX) / rayVectorX -- Distance from light to edge

							if t1 > 0 and t2 >= 0 and t2 <= 1.0 then -- Intersect point is valid
								if t1 < closest_t1 then 
									closest_t1 = t1
									closestPointX = sourceX + rayVectorX * t1
									closestPointY = sourceY + rayVectorY * t1
									closestAngle = math.atan2(closestPointY - sourceY, closestPointX - sourceX)
									isValid = true
								end
							end
						end
					end

					if isValid then 
						table.insert(visibillityPolygon, {closestPointX, closestPointY, closestAngle})
					end
				end
			end
		end
	table.sort(visibillityPolygon, function(a, b) return a[3] < b[3] end ) -- Sort points by angle
end


function newLight(x, y, color, power)
	table.insert(lights, {{x,y}, color, power})
	table.insert(lightMaps, love.graphics.newCanvas(800, 600))
end