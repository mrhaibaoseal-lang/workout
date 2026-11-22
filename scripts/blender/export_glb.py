import bpy
h=bpy.data.objects['hero']; h.modifiers.remove(h.modifiers['outline'])
bpy.ops.export_scene.gltf(filepath=bpy.path.abspath('//hero.glb'), export_animations=True, export_skins=True)
