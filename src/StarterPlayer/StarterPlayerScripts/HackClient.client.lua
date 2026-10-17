
--[[
    CIPHER BREACH - CLIENT SCRIPT
    -----------------------------
    Responsibilities:
    1. Create the hacking interface using Instances.
    2. Display the access code and countdown.
    3. Read the player's answer.
    4. Send valid submissions to the server.
    5. Display success, failure and expiry messages.

    SECURITY:
    The client handles presentation and user interaction.
    The server independently validates every submission.
    Client-side checks improve usability, but they are
    never a replacement for server-side validation.
]]


-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- LocalPlayer refers to the player using this client.
-- It is available in a LocalScript, not a normal Script.
local player = Players.LocalPlayer

-- Both sides must reference the same RemoteEvent instance.
local hackEvent = ReplicatedStorage:WaitForChild("HackEvent")


-- CREATE THE SCREEN GUI
-- ScreenGui contains the interface shown on the player's screen.
local gui = Instance.new("ScreenGui")
gui.Name = "CipherBreachUI"

-- Preserve the interface when the player's character respawns.
gui.ResetOnSpawn = false

-- Keep the interface hidden until a challenge starts.
gui.Enabled = false

-- Parent it to PlayerGui so Roblox displays it to the player.
gui.Parent = player:WaitForChild("PlayerGui")


-- REUSABLE INSTANCE CREATION HELPER
-- This function avoids repeating the same setup code whenever
-- we create a Frame, TextLabel, TextBox or other Instance.
--
-- className: Roblox class to create.
-- properties: table of property names and their values.
-- parent: Instance that should contain the new object.
--
-- It returns the created Instance so other code can modify it.
local function create(className, properties, parent)

	local object = Instance.new(className)

	-- Apply the supplied properties.
	for property, value in pairs(properties) do
		object[property] = value
	end

	-- Set the parent after configuring the properties.
	object.Parent = parent

	return object
end


-- MAIN TERMINAL PANEL
-- UDim2.fromOffset specifies a fixed pixel size.
-- UDim2.fromScale positions the panel relative to the screen.
-- AnchorPoint = (0.5, 0.5) makes the panel's centre align
-- with the centre of the screen.
local panel = create("Frame", {
	Name = "Terminal",
	Size = UDim2.fromOffset(360, 300),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(12, 20, 29),
}, gui)

-- Round the panel's corners for a cleaner appearance.
create("UICorner", {
	CornerRadius = UDim.new(0, 12),
}, panel)

-- Add a cyan outline to establish the hacking-terminal theme.
create("UIStroke", {
	Color = Color3.fromRGB(0, 220, 190),
	Thickness = 1.5,
}, panel)


-- REUSABLE TEXT LABEL HELPER
-- Centralises common label properties such as font,
-- position, size and colour.
local function makeLabel(name, text, position, size, color, textSize)

	return create("TextLabel", {
		Name = name,
		Text = text,
		Position = position,
		Size = size,

		-- Transparency of 1 hides the label's background
		-- while leaving its text visible.
		BackgroundTransparency = 1,

		TextColor3 = color,
		Font = Enum.Font.Code,
		TextSize = textSize,
	}, panel)
end


-- TITLE AND SUBTITLE
makeLabel(
	"Title",
	"CIPHER // BREACH",
	UDim2.fromOffset(20, 15),
	UDim2.new(1, -40, 0, 35),
	Color3.fromRGB(0, 255, 200),
	23
)

makeLabel(
	"Subtitle",
	"SECURE ACCESS TERMINAL",
	UDim2.fromOffset(20, 48),
	UDim2.new(1, -40, 0, 20),
	Color3.fromRGB(130, 160, 175),
	12
)


-- ACCESS CODE DISPLAY
-- The server supplies the code when the challenge begins.
-- This label is purely for displaying that information.
local codeLabel = makeLabel(
	"AccessCode",
	"ACCESS CODE: ----",
	UDim2.fromOffset(20, 83),
	UDim2.new(1, -40, 0, 40),
	Color3.fromRGB(255, 255, 255),
	22
)


-- COUNTDOWN DISPLAY
local timerLabel = makeLabel(
	"Timer",
	"TIME: 20",
	UDim2.fromOffset(20, 123),
	UDim2.new(1, -40, 0, 25),
	Color3.fromRGB(255, 190, 70),
	15
)


-- ANSWER INPUT BOX
-- TextBox allows the player to enter their four-digit answer.
local answerBox = create("TextBox", {
	Name = "Answer",
	PlaceholderText = "ENTER FOUR DIGITS",
	Text = "",

	-- Preserve the entered answer when the player focuses
	-- and then returns to the input box.
	ClearTextOnFocus = false,

	Position = UDim2.fromOffset(25, 160),
	Size = UDim2.new(1, -50, 0, 42),

	BackgroundColor3 = Color3.fromRGB(22, 36, 47),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	PlaceholderColor3 = Color3.fromRGB(110, 140, 155),

	Font = Enum.Font.Code,
	TextSize = 20,
}, panel)

create("UICorner", {
	CornerRadius = UDim.new(0, 6),
}, answerBox)


-- SUBMIT BUTTON
local submitButton = create("TextButton", {
	Name = "Submit",
	Text = "EXECUTE BREACH",

	Position = UDim2.fromOffset(25, 213),
	Size = UDim2.new(1, -50, 0, 38),

	BackgroundColor3 = Color3.fromRGB(0, 170, 145),
	TextColor3 = Color3.fromRGB(5, 15, 20),

	Font = Enum.Font.Code,
	TextSize = 16,
}, panel)

create("UICorner", {
	CornerRadius = UDim.new(0, 6),
}, submitButton)


-- STATUS MESSAGE
-- Used for input errors, verification and final results.
local statusLabel = makeLabel(
	"Status",
	"AWAITING INPUT",
	UDim2.fromOffset(15, 258),
	UDim2.new(1, -30, 0, 25),
	Color3.fromRGB(130, 200, 190),
	13
)


-- CLIENT CHALLENGE STATE
-- challengeToken distinguishes the current countdown task
-- from countdown tasks belonging to older challenges.
--
-- Incrementing the token invalidates an older task without
-- needing to forcibly cancel it.
local challengeToken = 0

-- active indicates whether the interface has an ongoing hack.
local active = false

-- submitted prevents multiple submissions from one challenge.
local submitted = false


-- SUBMIT ANSWER FUNCTION
-- Both the button and Enter key use this function.
-- This avoids duplicating submission logic in two callbacks.
local function submitAnswer()

	-- Ignore attempts if the challenge is not active or
	-- the player has already submitted an answer.
	if not active or submitted then
		return
	end

	local answer = answerBox.Text

	-- Provide immediate feedback for malformed input.
	-- This check is for usability; the server validates again.
	if not answer:match("^%d%d%d%d$") then

		statusLabel.Text = "ENTER EXACTLY FOUR DIGITS"
		statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

		return
	end

	-- Set submitted before firing the RemoteEvent.
	-- This prevents rapid clicks from sending duplicate requests.
	submitted = true

	-- Disable the button while the server processes the answer.
	submitButton.Active = false
	submitButton.AutoButtonColor = false

	statusLabel.Text = "VERIFYING..."

	-- Send the action and answer to the server.
	-- The server, not this script, determines the result.
	hackEvent:FireServer("Submit", answer)
end


-- CONNECT USER INPUT EVENTS
-- Activated works with mouse, touch and gamepad interaction.
submitButton.Activated:Connect(submitAnswer)

-- Allow players to submit by pressing Enter while the
-- answer TextBox loses focus.
answerBox.FocusLost:Connect(function(enterPressed)

	if enterPressed then
		submitAnswer()
	end
end)


-- HANDLE SERVER MESSAGES
-- OnClientEvent receives messages sent using FireClient.
hackEvent.OnClientEvent:Connect(function(action, value, durationOrMessage)

	-- START MESSAGE
	-- Arguments:
	-- action = "Start"
	-- value = access code
	-- durationOrMessage = challenge duration in seconds
	if action == "Start" then

		-- Invalidate countdown tasks from previous challenges.
		challengeToken += 1
		local token = challengeToken

		local duration = durationOrMessage

		active = true
		submitted = false

		-- Reveal the interface and reset previous input.
		gui.Enabled = true
		codeLabel.Text = "ACCESS CODE: " .. value
		answerBox.Text = ""

		statusLabel.Text = "ENTER THE ACCESS CODE"
		statusLabel.TextColor3 = Color3.fromRGB(130, 200, 190)

		-- Re-enable the submit button for the new challenge.
		submitButton.Active = true
		submitButton.AutoButtonColor = true

		-- Calculate the client-side display deadline.
		-- This controls the visual countdown only.
		-- The server independently checks its own deadline.
		local deadline = os.clock() + duration

		-- Run the countdown separately so the event handler
		-- can continue processing incoming server messages.
		task.spawn(function()

			-- Stop updating when the challenge token changes
			-- or the current challenge is no longer active.
			while token == challengeToken and active do

				local remaining = math.max(
					0,
					math.ceil(deadline - os.clock())
				)

				timerLabel.Text = "TIME: " .. remaining

				if remaining <= 0 then
					break
				end

				-- Refresh the display approximately ten times
				-- per second without running an endless busy loop.
				task.wait(0.1)
			end
		end)


		-- RESULT MESSAGE
		-- Arguments:
		-- action = "Result"
		-- value = true for success, false for failure
		-- durationOrMessage = result message
	elseif action == "Result" then

		-- Invalidate the countdown and mark the challenge done.
		challengeToken += 1
		active = false
		submitted = true

		local success = value
		local message = durationOrMessage

		-- Display the result supplied by the server.
		statusLabel.Text = message

		-- Use different colours to distinguish success and failure.
		statusLabel.TextColor3 = success
			and Color3.fromRGB(0, 255, 150)
			or Color3.fromRGB(255, 90, 90)

		if success then

			-- Display the reward confirmation.
			-- The server has already awarded the credits.
			timerLabel.Text = "REWARD: +100 CREDITS"

		else

			timerLabel.Text = "CHALLENGE FAILED"
		end

		-- Hide the interface after a short delay.
		-- Do not hide it if a new challenge has already started.
		task.delay(2, function()

			if not active then
				gui.Enabled = false
			end
		end)
	end
end)
