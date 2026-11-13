import subprocess, json, os, shutil

verison = json.loads(open("build.json").read())["version"]

try:
    shutil.rmtree("build")
except:
    print("build doesnt exist i think")
os.mkdir("build")



subprocess.run(f"rojo build -o build/Luma_{verison}.rbxmx",shell=True, cwd=os.getcwd())