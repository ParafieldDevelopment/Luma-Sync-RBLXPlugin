import subprocess, json, os, shutil

verison = json.loads(open("build.json").read())["version"]

shutil.rmtree("build")
os.mkdir("build")
subprocess.run(f"rojo build -o build/Luma_{verison}.rbxmx",shell=True)