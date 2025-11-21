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

**usage** `:Openner`

## Configuration

```lua
require("Openner").setup({
    default_command = { "am", "start", "--user", "0", "-n" }, -- default command to open a app
    applications = {
        Reddit = { -- open Reddit web
            name = "Reddit Web",
            command = { "termux-open-url" }, -- usage this command instead using default_command
            activity = "https://www.reddit.com/r/termux",
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

## Contribution
just create a PR and i will review it

## How to add a app

This plugin doesn't actually open the application, 
it just runs the `am start` command, so you can actually 
add any app as long as it's still possible to do so 
in neovim. All you need is `command` and `target`, 
for example:

```lua
foo = {
    name = "foo app",
    command = { "tmux", "neww" }, -- command
    activity = "python", -- target
    activated = true,
}
```

it's the same as running `tmux neww python`,
so with `am start` it just same like `am start --user 0 -n org.mozilla.firefox/.App`
and you must know activity app what you want to open

## About activity

you can get information about activity with application
named [apk info](https://play.google.com/store/apps/details?id=com.wt.apkinfo)

## App that have been setup
- Firefox
- DeepSeek
- Instagram
- YouTube

> [!IMPORTANT]
> This is not a perfect plugin maybe its not work
> in other phone, whether it's because the activity 
> is different or because Android is now getting stricter
