local rectangles = {}

local mouseDown = false
local newSize = 16

local shader = [[

	#define NUM_LIGHTS 32

	struct Light {
		vec2 position;
		vec3 diffuse;
		float power;
	};

	extern Light lights[NUM_LIGHTS];
	extern int num_lights;

	extern vec2 screenSize;

	const float constant = 1.0;
	const float linear = 0.09;
	const float quadratic = 0.032;

	extern Image lightMap;
	
	vec4 effect(vec4 color, Image image, vec2 uvs, vec2 screenCoords){

		vec4 pixel = Texel(image, uvs);

		vec2 normScreen = screenCoords / screenSize;
		vec3 diffuse = vec3(0);

		for (int i = 0; i < num_lights; i++){
			Light light = lights[i];
			vec2 normPos = light.position / screenSize;

			float distance = length(normPos - normScreen) * light.power;
			float attenuation = 1.0 / (constant + linear * distance + quadratic * (distance * distance));

			diffuse += light.diffuse * attenuation;
		}

		diffuse = clamp(diffuse, 0.0, 1.0);

		vec4 lightPixel = Texel(lightMap, normScreen);

		if (lightPixel[0] == 1.0){
			return pixel * vec4(diffuse, 1.0);
		}else{
			return vec4(0.0, 0.0, 0.0, 0.0);
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


	lightMap = love.graphics.newCanvas(800, 600)
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


	calculateVisibillityPolygon(mouseX, mouseY, 1000)
end

function love.draw()

	local mouseX, mouseY = love.mouse.getPosition()

	love.graphics.setCanvas(lightMap)
	love.graphics.clear()
	love.graphics.setColor(1,0,0)
	if #visibillityPolygon > 0 then 
		for i = 1, #visibillityPolygon-1 do
			--error( mouseX.. ", ".. mouseY.. "; "..visibillityPolygon[i][1].. ", ".. visibillityPolygon[i][2].. "; ".. visibillityPolygon[i+1][1].. ", ".. visibillityPolygon[i+1][2])
			love.graphics.polygon("fill", mouseX, mouseY, visibillityPolygon[i][1], visibillityPolygon[i][2], visibillityPolygon[i+1][1], visibillityPolygon[i+1][2])
		end
		love.graphics.polygon("fill", mouseX, mouseY, visibillityPolygon[#visibillityPolygon][1], visibillityPolygon[#visibillityPolygon][2], visibillityPolygon[1][1], visibillityPolygon[1][2])
	end
	love.graphics.setCanvas()


	love.graphics.setShader(shader)

	shader:send("screenSize", {love.graphics.getWidth(), love.graphics.getHeight()})
	shader:send("num_lights", 2)
	
	shader:send("lights[0].position", {love.mouse.getX(), love.mouse.getY()})
	shader:send("lights[0].diffuse", {1.0, 1.0, 1.0})
	shader:send("lights[0].power", 32)


	shader:send("lights[1].position", {150, 150})
	shader:send("lights[1].diffuse", {0.0, 1.0, 1.0})
	shader:send("lights[1].power", 32)

	shader:send("lightMap", lightMap)

	love.graphics.setColor(0,0,0)
	love.graphics.rectangle("fill", 0, 0, 800, 600)
	love.graphics.setColor(1,1,1)


	--[[for i,v in pairs(rectangles) do
		love.graphics.rectangle("fill", v.x, v.y, v.width, v.height)
	end
	--]]
	for i,v in pairs(edges) do
		love.graphics.line(v.x, v.y, v.endX, v.endY)
	end
	
	
	

	for i,v in pairs(visibillityPolygon) do
		--love.graphics.line(mouseX, mouseY, v[1], v[2])
	end

	--[[
	for i,v in pairs(edges) do
		love.graphics.circle("fill", v.x, v.y, 3)
		love.graphics.circle("fill", v.endX, v.endY, 3)
	end
	for i,v in pairs(visibillityPolygon) do
		love.graphics.circle("fill", v[1], v[2], 3)
		love.graphics.circle("fill", v[1], v[2], 3)
	end--]]
	love.graphics.draw(img, 500, 200)

	love.graphics.setShader()




	
end

function love.keypressed(key)
	if key == "escape" then 
		love.event.quit()
	end	
end


function calculateVisibillityPolygon(sourceX, sourceY, radius)
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
				for k = 0, 3 do 
					if k == 0 then angle = baseAngle - 0.0001 end
					if k == 1 then angle = baseAngle 		   end
					if k == 2 then angle = baseAngle + 0.0001 end

					rayVectorX = radius * math.cos(angle)
					rayVectorY = radius * math.sin(angle)

					local closest_t1 = 99999999
					local closestPointX = 0
					local closestPointY = 0
					local closestAngle = 0
					local isValid = false

					for l, edge2 in pairs(edges) do
						local sdx = edge2.endX - edge2.x
						local sdy = edge2.endY - edge2.y

						if math.abs(sdx - rayVectorX) > 0.0 and math.abs(sdy - rayVectorY) > 0.0 then -- Make sure vectors are not parralel
							local t2 = (rayVectorX * (edge2.y - sourceY) + (rayVectorY * (sourceX - edge2.x))) / (sdx * rayVectorY - sdy * rayVectorX)
							local t1 = (edge2.x + sdx * t2 - sourceX) / rayVectorX

							if (t1 > 0 and t2 >= 0 and t2 <= 1.0) then -- Intersect point is valid
								if (t1 < closest_t1) then 
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