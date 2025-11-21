# Openner.nvim

A simple neovim plugin to open a aplication in android,
like YouTube, Instagram even Web app

## installation

### lazy

```lua
return {
    "Hydra0xetc/Openner.nvim"
}
```

### packer 

```lua
use "Hydra0xetc/Openner.nvim"
```

usage `:Openner`

## Configuration

```lua
require("Openner").setup({
    default_command = { "am", "start", "--user", "0", "-n" }, -- default command to open a app
    applications = {
        Reddit = { -- open Reddit web
            name = "Reddit Web",
            command = { "termux-open-url" }, -- usage this command instead using default_command
            activity = "https://www.reddit.com/r/termux",
            activated = true, -- don't forget to activate it
        },
        Youtube = {
            activated = false, -- disable default YouTube aplication
        }
    },
    window = {
		width = 50,
		height = 10,
        border = "rounded", -- single, double, rounded, none, shadow, solid
        title = "Applications",
        title_pos = "center", -- left, right, center
    },
})
```

## Adding aplication

> [!IMPORTANT]
> This is not a perfect plugin maybe its not work
> 
