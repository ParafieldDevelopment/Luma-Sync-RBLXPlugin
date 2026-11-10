# Luma IDE Sync ( Roblox Studio Plugin )

Brings the ability to sync the IDE and roblox. 

# Developing

To develop this plugin you will need the Rokit and Rojo toolchains along with Visual Studio Code with the Luau Language Server.

```sh
rokit install
```

and to sync the sourcemap to the IDE use

```sh
rojo sourcemap --watch default.project.json --output sourcemap.json
```
