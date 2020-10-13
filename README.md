# Shell Fur and Grass Add-on for Godot Engine

![image](https://user-images.githubusercontent.com/4955051/95903332-e9438c00-0d8d-11eb-9c76-368189795cff.png)

Add-on that adds a fur node to Godot 3.2.


Instalation
-----------
Copy the folder addons/shell_fur into your project and activate the add-on from the **Project -> Project Settings... -> Plugins** menu.

Purpose
-------
I was inspired by games like Shadow of the Colossus and Red Dead Redemption 2 which used this technique to try and make my own implementation in Godot.

Usage
-----
Select any MeshInstance node and add the ShellFur node as a child beneath it.

![image](https://user-images.githubusercontent.com/4955051/95904767-da5dd900-0d8f-11eb-8d1e-397e6bacbd66.png)

![image](https://user-images.githubusercontent.com/4955051/95904873-037e6980-0d90-11eb-8c85-78fd65ee06b3.png)

![image](https://user-images.githubusercontent.com/4955051/95905031-39235280-0d90-11eb-88a9-1840da7de408.png)

If you select the added fur node you will see the fur settings available in the inspector.

![image](https://user-images.githubusercontent.com/4955051/95905255-84d5fc00-0d90-11eb-8920-3d26dea04576.png)

Most of the options should be self explanatory. But a few are a bit more specific.

- The **Pattern Selector** parameter allows you to set the pattern texture between three included patterns: Fine Hair, Rough Hair and Moss. The pattern textures consist of two channels, the red channel which decides the thickness of the hair along the strand and the green channel which is used to allow variation in length. You can manually select other textures using the **Pattern Texture** parameter, but random length will only work if you correctly set up the channels.

Left: Fine Hair, Middle: Rough Hair, Right: Moss
![image](https://user-images.githubusercontent.com/4955051/95911309-3842ee80-0d99-11eb-9acf-54d6062179e8.png)

Breakdown of Fine Hair texture - Left: Combined pattern texture, Middle: R channel, Right: G channel
![image](https://user-images.githubusercontent.com/4955051/95909140-e64c9980-0d95-11eb-8a78-9f864b7abe19.png)

- The **layers** parameter controls how many shells are generated around the object, more layers equals nicer strands, but will decrease performance.

12 layers on the left. 40 layers on the right.
![image](https://user-images.githubusercontent.com/4955051/95906679-58bb7a80-0d92-11eb-946c-f3f319004f56.png)

- The **Use Blendshape** option allows you to style the fur with a blendshape. The **Blendshape Index** allows you to choose which blendshape on the base mesh to use.

Top: Base mesh, Middle: Blendshape, Bottom: Fur styled by blendshape
![image](https://user-images.githubusercontent.com/4955051/95907763-f794a680-0d93-11eb-948b-23ab3420f41a.png)

Current Limitations
-------------------
- No wind or other physics currently.
- No LOD system currently.
- While the fur can be styled with blendshapes, it does not currently inheirit the blendshapes from the mesh, so it is not possible to deform the base mesh with blendshapes and have the fur follow the shape.
- The normals are not corrected along the fur strands, so low roughness settings will not look correct.
