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
