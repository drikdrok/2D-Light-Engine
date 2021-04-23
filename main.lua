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

		return pixel * vec4(diffuse, 1.0);
	}

]]




function love.load()
	shader = love.graphics.newShader(shader)
	img = love.graphics.newImage("img.png")
end

function love.update(dt)
	if love.mouse.isDown(1) then 
		if mouseDown then 
			rectangles[#rectangles].width = rectangles[#rectangles].width + 1
			rectangles[#rectangles].height = rectangles[#rectangles].height + 1
		else
			mouseDown = true
			table.insert(rectangles, {x = love.mouse.getX(), y = love.mouse.getY(), width = 16, height = 16})
		end
	else
		mouseDown = false
	end
end

function love.draw()
	love.graphics.setShader(shader)

	shader:send("screenSize", {love.graphics.getWidth(), love.graphics.getHeight()})
	shader:send("num_lights", 1)
	
	shader:send("lights[0].position", {love.mouse.getX(), love.mouse.getY()})
	shader:send("lights[0].diffuse", {1.0, 1.0, 1.0})
	shader:send("lights[0].power", 32)

	love.graphics.draw(img, 500, 200)

	for i,v in pairs(rectangles) do
		love.graphics.rectangle("fill", v.x, v.y, v.width, v.height)
	end
	love.graphics.setShader()
end

function love.keypressed(key)
	if key == "escape" then 
		love.event.quit()
	end	
end

function love.mousepressed(x, y)
	
end