"""Author Captain Live's hollow tricorn and detachable plume in Blender.

blender -b --factory-startup --python tools/build_captain_hat.py -- --out DIRECTORY
Geometry and diffuse-only albedo are authored here; no source mesh is imported.
Blender coordinates: X right, -Y front, Z up; exported glTF: +Y up, +Z front.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

args = argparse.ArgumentParser()
args.add_argument('--out', required=True)
out = Path(args.parse_args(sys.argv[sys.argv.index('--') + 1:]).out).resolve()
out.mkdir(parents=True, exist_ok=True)
source = out/'source'
source.mkdir(exist_ok=True)
(source/'.gdignore').write_text('')
bpy.ops.wm.read_factory_settings(use_empty=True)


def xyz(p):
    return Vector((p[0], -p[2], p[1]))


def material(name, dark, light):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    emission = nodes.new('ShaderNodeEmission')
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 6.0
    noise.inputs['Detail'].default_value = 1.2
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light, 1)
    links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], emission.inputs['Color'])
    links.new(emission.outputs[0], output.inputs[0])
    return mat


felt = material('Warm charcoal felt', (.022, .018, .015), (.050, .037, .027))
gold = material('Worn ochre piping', (.22, .078, .014), (.48, .235, .060))
band = material('Dark leather band', (.020, .009, .004), (.067, .026, .010))
scarlet = material('Scarlet plume', (.39, .002, .007), (.78, .009, .021))
quill_mat = material('Red quill', (.20, .001, .003), (.43, .004, .008))


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for face in data.polygons:
        face.use_smooth = True
    return obj


def tube(name, points, radius, mat, sides=6):
    verts, faces = [], []
    for i, p in enumerate(points):
        tangent = (points[min(i+1, len(points)-1)] - points[max(i-1, 0)]).normalized()
        side = tangent.cross(Vector((0, 1, 0))).normalized()
        normal = tangent.cross(side).normalized()
        for j in range(sides):
            a = j * math.tau / sides
            verts.append(p + radius * (math.cos(a)*side + math.sin(a)*normal))
    for i in range(len(points)-1):
        for j in range(sides):
            faces.append((i*sides+j, i*sides+(j+1)%sides,
                          (i+1)*sides+(j+1)%sides, (i+1)*sides+j))
    faces += [tuple(reversed(range(sides))), tuple((len(points)-1)*sides+j for j in range(sides))]
    return mesh(name, verts, faces, mat)


def cubic(a, b, c, d, t):
    return (1-t)**3*a + 3*(1-t)**2*t*b + 3*(1-t)*t*t*c + t**3*d


# A single brim surface with front folds and a third rear point, not stacked hats.
outline = [xyz(p) for p in [
    (0,.155,.17), (.07,.238,.12), (.14,.182,.10), (.23,.084,.075),
    (.32,.025,.025), (.24,.070,-.105), (.13,.110,-.210), (0,.145,-.285),
    (-.13,.110,-.210), (-.24,.075,-.105), (-.32,.025,.025),
    (-.23,.105,.075), (-.14,.208,.10), (-.07,.250,.12)]]
rim = []
for i in range(len(outline)):
    p0,p1,p2,p3 = [outline[j%len(outline)] for j in (i-1,i,i+1,i+2)]
    for k in range(6):
        t=k/6
        rim.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t**3))
n = len(rim)
verts, faces = [], []
for ring in range(9):
    t=ring/8
    for p in rim:
        angle=math.atan2(p.x, -p.y)
        inner=Vector((.108*math.sin(angle), -.132*math.cos(angle), .028+.052*max(0,math.cos(angle))**2))
        v=inner.lerp(p,t)
        v.z=inner.z+(p.z-inner.z)*t**1.9 + .018*math.sin(math.pi*t)
        v.z+=.010*math.sin(math.pi*t)*math.sin(angle*5+t*3)
        verts.append(v)
for ring in range(8):
    for j in range(n):
        a=ring*n+j; b=ring*n+(j+1)%n
        faces.append((a,b,b+n,a+n))
brim=mesh('FoldedBrim',verts,faces,felt)
solid=brim.modifiers.new('Felt thickness','SOLIDIFY'); solid.thickness=.007
solid.offset=-1
bpy.context.view_layer.objects.active=brim
bpy.ops.object.modifier_apply(modifier=solid.name)

# Dome crown: deliberately open at the underside, with a real head opening.
verts,faces=[],[]
segments=48
for ring in range(11):
    a=ring/10*math.pi/2
    radius=max(.002,math.cos(a))
    for j in range(segments):
        theta=j*math.tau/segments
        verts.append((.110*radius*math.sin(theta), -.135*radius*math.cos(theta), .025+.178*math.sin(a)+.046*max(0,math.cos(theta))**2*math.cos(a)**2))
for ring in range(10):
    for j in range(segments):
        a=ring*segments+j; b=ring*segments+(j+1)%segments
        faces.append((a,b,b+segments,a+segments))
faces.append(tuple(10*segments+j for j in range(segments)))
crown=mesh('HollowCrown',verts,faces,felt)
solid=crown.modifiers.new('Crown thickness','SOLIDIFY'); solid.thickness=.006; solid.offset=-1
bpy.context.view_layer.objects.active=crown
bpy.ops.object.modifier_apply(modifier=solid.name)
edge=tube('GoldBrimEdge',rim+[rim[0]],.0023,gold)
hat_objects=[brim,crown,edge]

# One arcing feather. Every pointed vane grows from the same curved quill.
p0,p1,p2,p3=[xyz(p) for p in [(.040,.185,-.012),(.016,.505,.075),(.485,.480,-.170),(.370,.050,-.190)]]
def stem(t): return cubic(p0,p1,p2,p3,t)
quill=tube('FeatherQuill',[stem(i/64) for i in range(65)],.0033,quill_mat,8)
feather_objects=[quill]
for side in (-1,1):
    for i in range(18):
        t=.07+i*.048
        base=stem(t)
        ahead=stem(min(1,t+.15))
        tangent=(stem(min(1,t+.015))-stem(max(0,t-.015))).normalized()
        outward=Vector((-tangent.z,0,tangent.x))*side
        length=(.095 if side==-1 else .120)*math.sin(math.pi*(.15+t*.75))*(1+.08*math.sin(i*2.4))
        tip=stem(min(1,t+.23))+outward*length
        tip.y+=.023*math.sin(i*1.7+side)
        b=base+tangent*.065+outward*.025
        c=tip-tangent*.043-outward*.005
        points=[cubic(base,b,c,tip,k/12) for k in range(13)]
        vv,ff=[],[]
        width=(.012 if side==-1 else .017)*(1-.25*t)
        for k,p in enumerate(points):
            u=k/12
            tang=(points[min(k+1,12)]-points[max(k-1,0)]).normalized()
            perp=Vector((-tang.z,0,tang.x)).normalized()
            w=max(.0002,width*math.sin(math.pi*u)**.65)
            for offset in [perp*w,Vector((0,-w*.32,0)),-perp*w,Vector((0,w*.32,0))]:
                vv.append(p+offset)
        for k in range(12):
            for j in range(4):
                ff.append((k*4+j,k*4+(j+1)%4,(k+1)*4+(j+1)%4,(k+1)*4+j))
        ff += [(3,2,1,0),(48,49,50,51)]
        feather_objects.append(mesh('Barb_%s_%02d'%(side,i),vv,ff,scarlet))


def combine(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    o=bpy.context.object; o.name=name
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(angle_limit=math.radians(65),island_margin=.012)
    bpy.ops.object.mode_set(mode='OBJECT')
    return o


hat=combine(hat_objects,'TricornHat')
feather=combine(feather_objects,'ScarletFeather')
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=1
scene.render.bake.margin=12


def bake_albedo(obj,name,size):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True); bpy.context.view_layer.objects.active=obj
    image=bpy.data.images.new(name,width=size,height=size,alpha=False)
    for mat in obj.data.materials:
        node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=image
        mat.node_tree.nodes.active=node
    bpy.ops.object.bake(type='EMIT')
    image.filepath_raw=str(out/(name+'.png')); image.file_format='PNG'; image.save()
    image.pack()
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value=.83
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image
    mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    obj.data.materials.clear(); obj.data.materials.append(mat)
    for p in obj.data.polygons: p.material_index=0


bake_albedo(hat,'hat_albedo',1024)
bake_albedo(feather,'feather_albedo',512)
for obj,name in [(hat,'hat'),(feather,'feather')]:
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out/'hat_with_feather.glb'),export_format='GLB',use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'captain_hat.blend'))
stats={}
for obj in (hat,feather):
    obj.data.calc_loop_triangles()
    stats[obj.name]={'vertices':len(obj.data.vertices),'triangles':len(obj.data.loop_triangles),
                     'dimensions_xyz_blender_m':list(obj.dimensions)}
(out/'mesh_report.json').write_text(json.dumps(stats,indent=2)+'\n')

# Preview illumination is separate from the albedo bake.
scene.render.engine='BLENDER_EEVEE_NEXT'
scene.world=bpy.data.worlds.new('PreviewWorld')
scene.world.color=(.16,.16,.16)
scene.view_settings.view_transform='Standard'
scene.render.resolution_x=800; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=True
for name,pos,power,size in [('Key',(-1,-2,2),100,3),('Fill',(2,-1,1),65,3),('Rim',(-1,2,1.5),85,2)]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    light=bpy.data.objects.new(name,data); scene.collection.objects.link(light)
    light.location=pos; light.rotation_euler=(Vector((0,0,.20))-light.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('PreviewCamera'); camera=bpy.data.objects.new('PreviewCamera',data)
scene.collection.objects.link(camera); scene.camera=camera
data.type='ORTHO'; data.ortho_scale=.95
target=Vector((.04,0,.24))
for name,pos in [('front',(.04,-3,.24)),('left',(-3,0,.24)),('right',(3,0,.24)),('back',(.04,3,.24)),('three_quarter',(1.5,-3,1.15)),('underside',(1,-2,-1.3))]:
    camera.location=pos; camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(source/('preview_'+name+'.png')); bpy.ops.render.render(write_still=True)
print('AUTHORED_HAT',json.dumps(stats))
