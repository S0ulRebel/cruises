"""Extract the previous Tripo plume and pair it with the handmade tricorn.

blender -b --factory-startup --python tools/reuse_captain_feather.py -- \
    --source OLD_HAT.glb --hat NEW_HAT.glb --out DIRECTORY [--preview IMAGE.png]

The old plume is fused to the old hat. Select faces by their scarlet texture,
retaining the source UVs/material/normals. No GPU or game is used. Optional
preview is explicitly rendered with Cycles CPU only.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
import numpy as np

parser=argparse.ArgumentParser()
parser.add_argument('--source',required=True)
parser.add_argument('--hat',required=True)
parser.add_argument('--out',required=True)
parser.add_argument('--preview')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
out=Path(args.out).resolve(); out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(args.source).resolve()))
feather=max((o for o in bpy.data.objects if o.type=='MESH'),key=lambda o:len(o.data.vertices))
image=next(n.image for n in feather.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
pixels=np.empty(len(image.pixels),dtype=np.float32)
image.pixels.foreach_get(pixels)
pixels=pixels.reshape((image.size[1],image.size[0],4))
uv=feather.data.uv_layers.active.data
selected=[]
for face in feather.data.polygons:
    samples=[uv[i].uv.copy() for i in face.loop_indices]
    samples.append(sum(samples,samples[0]*0)/len(samples))
    votes=0
    for p in samples:
        r,g,b=pixels[int(p.y*image.size[1])%image.size[1],int(p.x*image.size[0])%image.size[0],:3]
        votes+=bool(r>.15 and r>g*3.5 and r>b*2.5 and b>=g*.75)
    if votes>=len(samples)/2: selected.append(face.index)
if not selected: raise RuntimeError('No scarlet feather faces found')
selected=set(selected)
# Discard isolated gold/ochre hat edges that can look red in the texture.
# Compare positions rather than mesh indices, because UV seams split vertices.
positions={}
for i in selected:
    for v in feather.data.polygons[i].vertices:
        key=tuple(round(c,6) for c in feather.data.vertices[v].co)
        positions.setdefault(key,set()).add(i)
neighbors={i:set() for i in selected}
for group in positions.values():
    for i in group: neighbors[i].update(group)
components=[]; unseen=set(selected)
while unseen:
    seed=unseen.pop(); component={seed}; queue=[seed]
    while queue:
        i=queue.pop()
        found=neighbors[i]&unseen
        unseen.difference_update(found); component.update(found); queue.extend(found)
    components.append(component)
selected=max(components,key=len)
bm=bmesh.new(); bm.from_mesh(feather.data); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in selected],context='FACES_ONLY')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bm.to_mesh(feather.data); bm.free(); feather.data.update()
for o in list(bpy.data.objects):
    if o is not feather: bpy.data.objects.remove(o,do_unlink=True)
feather.name='OriginalScarletFeather'

# Uniform fit into the handmade hat's local metre coordinates; bake into mesh.
scale=.80
offset=Vector((.040,-.105,-.060))
matrix=feather.matrix_world.copy()
for v in feather.data.vertices: v.co=(matrix@v.co)*scale+offset
feather.matrix_world.identity()
feather.data.update()
bpy.ops.object.select_all(action='DESELECT'); feather.select_set(True)
bpy.context.view_layer.objects.active=feather
bpy.ops.export_scene.gltf(filepath=str(out/'feather_original.glb'),export_format='GLB',use_selection=True)

feather.data.calc_loop_triangles()
stats={'source_sha256':hashlib.sha256(Path(args.source).read_bytes()).hexdigest(),
       'extraction':'Majority scarlet samples (R>0.15, R>3.5G, R>2.5B, B>=0.75G); retain largest position-connected face region, discard old hat fragments.',
       'source_faces_retained':len(selected),'triangles':len(feather.data.loop_triangles),
       'vertices':len(feather.data.vertices),'uniform_scale':scale,
       'translation_blender_xyz':list(offset),'texture':'Original embedded Tripo 2048px texture, preserved',
       'bounds_blender_xyz':[[min(v.co[i] for v in feather.data.vertices) for i in range(3)],
                             [max(v.co[i] for v in feather.data.vertices) for i in range(3)]],
       'limitation':'Extraction follows the scarlet material boundary of the fused source; mounting is a first fit.'}
(out/'feather_original.json').write_text(json.dumps(stats,indent=2)+'\n')

bpy.ops.import_scene.gltf(filepath=str(Path(args.hat).resolve()))
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type=='MESH': o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out/'hat_with_original_feather.glb'),export_format='GLB',use_selection=True)
source=out/'source'; source.mkdir(exist_ok=True); (source/'.gdignore').write_text('')
bpy.ops.wm.save_as_mainfile(filepath=str(source/'captain_hat_original_feather.blend'))
print('EXTRACTED_FEATHER',json.dumps(stats))

if args.preview:
    scene=bpy.context.scene
    scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=128
    scene.cycles.use_denoising=False
    scene.render.resolution_x=800; scene.render.resolution_y=800; scene.render.resolution_percentage=100
    scene.render.film_transparent=True; scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='Standard'
    scene.world=bpy.data.worlds.new('CPUPreviewWorld'); scene.world.color=(.16,.16,.16)
    target=Vector((.05,0,.22))
    for name,pos,power,size in [('Key',(-1,-2,2),100,3),('Fill',(2,-1,1),65,3),('Rim',(-1,2,1.5),85,2)]:
        data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
        light=bpy.data.objects.new(name,data); scene.collection.objects.link(light)
        light.location=pos; light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
    data=bpy.data.cameras.new('CPUPreviewCamera'); camera=bpy.data.objects.new('CPUPreviewCamera',data)
    scene.collection.objects.link(camera); scene.camera=camera
    data.type='ORTHO'; data.ortho_scale=1.0
    camera.location=(1.0,-3,1.0)
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(Path(args.preview).resolve())
    bpy.ops.render.render(write_still=True)
