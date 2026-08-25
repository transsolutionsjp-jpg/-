#!/usr/bin/env python3
"""
src/ の Luau ファイルから、Roblox Studio へ直接読み込める
.rbxmx（Roblox モデル XML）を生成する。

Rojo を使わない相手にコードを渡すための補助ツール。
src/ を変更したら実行し直すこと。

    python3 tools/build_install.py
"""

import os
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HEADER = (
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
)
FOOTER = "</roblox>\n"

BUNDLES = [
    ("install/1_ReplicatedStorage.rbxmx", [
        ("src/ReplicatedStorage/GameConfig.lua", "ModuleScript", "GameConfig"),
    ]),
    ("install/2_ServerScriptService.rbxmx", [
        ("src/ServerScriptService/SV_Net.lua",         "ModuleScript", "SV_Net"),
        ("src/ServerScriptService/SV_State.lua",       "ModuleScript", "SV_State"),
        ("src/ServerScriptService/SV_Character.lua",   "ModuleScript", "SV_Character"),
        ("src/ServerScriptService/SV_Combat.lua",      "ModuleScript", "SV_Combat"),
        ("src/ServerScriptService/SV_Bleed.lua",       "ModuleScript", "SV_Bleed"),
        ("src/ServerScriptService/SV_TestArena.lua",   "ModuleScript", "SV_TestArena"),
        ("src/ServerScriptService/SV_Main.server.lua", "Script",       "SV_Main"),
    ]),
    ("install/3_StarterPlayerScripts.rbxmx", [
        ("src/StarterPlayerScripts/CL_Combat.client.lua", "LocalScript", "CL_Combat"),
        ("src/StarterPlayerScripts/CL_HUD.client.lua",    "LocalScript", "CL_HUD"),
    ]),
]


def item(cls, name, source, ref):
    # Luau の長括弧コメントが CDATA を閉じてしまわないよう逃がす
    safe = source.replace("]]>", "]]]]><![CDATA[>")
    return (
        '\t<Item class="%s" referent="RBX%d">\n'
        "\t\t<Properties>\n"
        '\t\t\t<bool name="Disabled">false</bool>\n'
        '\t\t\t<string name="Name">%s</string>\n'
        '\t\t\t<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>\n'
        "\t\t</Properties>\n"
        "\t</Item>\n"
    ) % (cls, ref, name, safe)


def build():
    os.makedirs(os.path.join(ROOT, "install"), exist_ok=True)
    written = []

    for out, files in BUNDLES:
        buf = [HEADER]
        for i, (path, cls, name) in enumerate(files):
            with open(os.path.join(ROOT, path), encoding="utf-8") as f:
                buf.append(item(cls, name, f.read(), i))
        buf.append(FOOTER)

        out_path = os.path.join(ROOT, out)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write("".join(buf))
        written.append((out, len(files)))

    return written


def verify():
    """生成した XML が壊れておらず、ソースが元ファイルと完全一致するか確かめる"""
    expected = {name: path for _, files in BUNDLES for path, _, name in files}
    seen = set()

    for out, _ in BUNDLES:
        root = ET.parse(os.path.join(ROOT, out)).getroot()
        for node in root.findall("Item"):
            name = node.find('Properties/string[@name="Name"]').text
            src = node.find('Properties/ProtectedString[@name="Source"]').text
            with open(os.path.join(ROOT, expected[name]), encoding="utf-8") as f:
                original = f.read()
            if src != original:
                raise SystemExit("ソースが一致しません: %s" % name)
            seen.add(name)

    missing = set(expected) - seen
    if missing:
        raise SystemExit("生成されていません: %s" % ", ".join(sorted(missing)))

    return len(seen)


if __name__ == "__main__":
    for out, count in build():
        print("%-40s %d件" % (out, count))
    print("検証: %d件のソースが元ファイルと完全一致" % verify())
