# Shell Fur Add-on for Godot Engine

[![Shell Fur Add-on for Godot v0.1.0 Released - Feature Overview](https://user-images.githubusercontent.com/4955051/97077434-8b0f7800-15db-11eb-98eb-7cecf1648304.png)](https://youtu.be/7EUjxwGTPAI "Shell Fur Add-on for Godot v0.1.0 Released - Feature Overview")

Add-on that adds a fur node to Godot 3.2. Demo project available [here.](https://github.com/Arnklit/ShellFurGodotDemo)

[Discord Server](https://discord.gg/mjGvWwQwv2)

[Patreon](https://www.patreon.com/arnklit)

Installation
-----------
ShellFur is available on the Godot Asset Library, so the easiest way to install it into your project is directly inside Godot. Simply go to the AssetLib screen and search for "Fur" and the add-on should appear. Select it and press Download -> Install.

Alternatively you can press the green **Code** button at the top of this page and select **Download ZIP**, unzip the file and place the "shell_fur" folder in your project like so "addons/shell_fur*.

Once the files are in your project, you need to activate the add-on from the *Project -> Project Settings... -> Plugins* menu.

Purpose
-------
I was inspired by games like Shadow of the Colossus and Red Dead Redemption 2 which use this technique, to try and make my own implementation in Godot.

Warning
-------
This tool is not meant for grass and foliage. This method is way too performance expensive on fillrate when the fur takes up large parts of the screen for it to be used for effects like that. Use the effect for hero props or characters.

Usage
-----
Select any *MeshInstance* node and add the *ShellFur* node as a child beneath it.

![72mqYGVOST](https://user-images.githubusercontent.com/4955051/111127735-0f06d400-856c-11eb-8ac3-f69a85c5c072.gif)



Parameters
-----
The parameters for the fur is split into five sections.

**Main**

- **Shader Type** - This allows you to select between shaders, the options are *Regular*, *Mobile* and *Custom* (*Custom* only appears when a shader is set in the *Custom Shader* field). The *Mobile* shader differs from the *Regular* shader in that it does not use depth_draw_alpha_prepass as that does not work well in my testing on Android, it also uses simpler diffuse and specular shading and disables shadows on the fur. Note: Both *Regular* and *Mobile* shaders work with GLES2.
- **Custom Shader** - This option allows you to use a custom shader, selecting new will clone the currently active shader for you to edit.
- **Layers** - The amount of shells that are generated around the object, more layers equals nicer strands, but will decrease performance.
- **Pattern Selector** - This options allows you to select between the five included patterns.
![image](https://user-images.githubusercontent.com/4955051/97798110-fe883980-1c1a-11eb-9efd-66369c21b8d0.png)
- **Pattern Texture** - The pattern texture in use, use this to manually set your own pattern for the fur shape, if none of the built-in ones fit your purpose. See info on making your own patterns below.
- **Pattern UV Scale** - The scale of the pattern texture on the model, increase this to make more dense and thin fur.
- **Cast Shadow** - Whether the fur should cast shadow. This is expensive performance wise, so it defaults to off.

**Material**

*The material subsection is dynamically generated based on the content of the shader in use. The Regular and Mobile shader have the same shader parameters, but if you choose to customize the shader any parameters you add will be displayed here. See writing custom shaders for details.*

- **Transmission:** - The amount of light that can pass through the fur and the color of that light.
- **Ao:** - Fake ambient occlusion applied linearly from the base to the tip.
- **Roughness** - The roughness value of the fur, it's difficult to achieve realistic shiny fur with this approach, you will probably get the best result leaving this value at 1.0.
- **Albedo** - Subcategory for albedo parameters.
  - **Color** - Color gradient used for the albedo of the fur, left is base of the fur, right is tip. The color interpolates linearly between the two.
  - **UV Scale** - UV Scale for the albedo texture below.
  - **Texture** - Texture for the color of the strands. Values are multiplied with the *Color* gradient so it can be used for tinting.
- **Shape** - Subcategory for the shape parameters.
  - **Length** - The length of the fur. Set this to 1.0 if you are using blendshape styling and want the fur to exactly reach the blendshape key.
  - **Length Rand** - Controls how much randomness there is in the length of the fur.
  - **Density** - Lowering the value with randomly discard more and more hair strands for a more sparse look.
  - **Thickness Base** - The thickness at the base of the strand.
  - **Thickness Tip** - The thickness at the tip of the strand.
  - **Thickness Rand** - Controls how much the thickness of each strand gets multiplied with a with a random value.
  - **Growth** - This control can be animated either with an animation player node or a script for fur growth effect.
  - **Growth Rand** - This adds a random offset to the growth of each strands.
  - **ldtg UV Scale** - UV Scale for the ldtg texture below.
  - **ldtg Textire** - An RGBA texture that can be used to customize the Length(R), Density(G), Thichkness(B) and Growth(A) parameters.

**Physics**

- **Custom Physics Pivot** - If you are using the fur on a skinned mesh where animation is moving the mesh, use this option to set the physics pivot to the center of gravity of your character. You can use the *Bone Attachment* node to set up a node that will follow a specific bone in your rig.
- **Gravity** - Down force applied on the spring physics.
- **Spring** - Amount of springiness to the physics.
- **Damping** - Amount of damping to the physics (to imitate air and friction resistance stopping the fur's movement over time).
- **Wind Strength** - Amount of wind strength, the wind is applied as a noise distortion in the vertex shader due to current limitations so it does not interact with the spring physics. If the *Wind Strength* is set to 0 the calculations are skipped in the shader.
- **Wind Speed** - How quickly the wind noise moves accross the fur.
- **Wind Scale** - Scale of the wind noise.
- **Wind Angle** - The angle the wind pushes in degrees around the Y-axis. 0 means the wind is blowing in X- direction.

*Spring physics and wind in action*

![OjUGl0gCwP](https://user-images.githubusercontent.com/4955051/111274147-9025a000-862c-11eb-8e05-665b63d36265.gif)

**Blendshape Styling**

- **Blendshape** - This pull down will list any blendshapes available on your base mesh. Selecting one of them will activate *Blendshape Styling*.
- **Normal Bias** - This option only appears when a blendshape is selected above. This option mixes the fur direction of the blendshape with the normal direction of the base shape for a more natural look.

*Blendshape styling being applied*

![JKYwI1ItFD](https://user-images.githubusercontent.com/4955051/111274654-2bb71080-862d-11eb-8696-60dab4515434.gif)

**Lod**

- **Lod 0 Distance** - The distance up to which the fur will display at full detail.
- **Lod 1 Distance** - The distance at which the fur will display at 25% of it's layers. The fur will smoothly interpolate between *Lod 0* and *Lod 1*. Beyond *Lod 1* distance the fur will fade away and the fur object will become hidden.

API
---

If you want to communicate with the fur script with your own scripts you can call all the public setters and getters on the tool, in addition to the setters for the parameters seen in the inspector, these three functions may be useful.

|Function                                |Return Type |Description                                                               |
|:---------------------------------------|:-----------|:-------------------------------------------------------------------------|
|get_current_LOD()                       |int         |Returns the current LOD level                                             |
|get_shader_param(param : String)        |variant     |Returns the given shader parameter                                        |
|set_shader_param(param : String, value) |void        |Sets the given shader parameter - DO NOT SET INTERNAL PARAMS (prefix "i_")|

TIPS
----

**Using your own fur patterns**

If you want to use your own pattern for the fur, you need use a texture with noise in the R channel used for the fur strand cutoff. You can leave G, B and A channel at full value and the shader will work, but you will not have any options for random length, density, thickness and growth. To have that you'll need to have random values corresponding to the cells of each strand in those channels as seen below.

Breakdown of *Very Fine* texture - Left to right: Combined pattern texture, R channel, G channel, B channel and A channel.
![image](https://user-images.githubusercontent.com/4955051/111150649-41bdc600-8586-11eb-9dad-9def3a252be1.png)

The easiest way to do this is to use this [file](https://github.com/Arnklit/media/blob/main/ShellFurAdd-on/pattern_examples.ptex) which shows examples of how I generate fur textures. It is made in the free Texture generation program [Material Maker](https://github.com/RodZill4/material-maker).

Be sure to enable *Filter*, *Mipmaps* and *Anisotropic* and set *Srgb* to *Disable* when importing your own pattern textures.

**Writing Custom Shaders**

When writing custom shaders for the tool there are a few things to keep in mind.

The tool uses certain uniforms that should not be customized as that will break the tool. These uniforms are prefixed with "i_" and are:

|Uniform name            |Description                                                  |
|:-----------------------|:------------------------------------------------------------|
|i_layers                |Used by the shader to correctly spread the layers            |
|i_pattern_texture       |The pattern texture set by the selector in the main section  |
|i_pattern_uv_scale      |UV scale of the above texture                                |
|i_wind_strength         |Controls for the wind system                                 |
|i_wind_speed            |Controls for the wind system                                 |
|i_wind_scale            |Controls for the wind system                                 |
|i_wind_angle            |Controls for the wind system                                 |
|i_normal_bias           |Used to blend in the normal at the base when using blendshape|
|i_LOD                   |Used by the LOD system                                       |
|i_physics_pos_offset    |Used by the physics system to pass spring data               |
|i_physics_rot_offset    |Used by the physics system to pass spring data               |
|i_blend_shape_multiplier|Used when setting up the extrusion vectors for the shells    |
|i_fur_contract          |Used by the LOD system to pull the fur into the mesh         |

Uniforms that do not start with "i_" will be parsed by the ShellFur's material inspector so they can easily be used in the tool. If the uniforms start with any of the below prefixes they will automatically be sorted into subcategories in the material section.

|Prefix name  |Subcategory name|
|:------------|:----------------|
|albedo_      |Albedo           |
|shape_       |Shape            |
|custom_      |Custom           |

*mat4 uniforms containing "color" in their name will be displayed as a gradient field with two color selectors.*

**Mobile Support - experimental**

The shader works with GLES2, however rotational physics and Custom Physics Pivot does not work in GLES2.

I suggest using the *Mobile* shader when targeting mobile, but if you have a newer device, the *Regular* shader might work as well.

In my testing there appeared to be a bug where skinned meshes with blendshapes don't render on Android. https://github.com/godotengine/godot/issues/43217. So if you want to use blendshape styling, you might need to work around this by having a separate mesh where you have removed the blendshape, that is getting rendered. I had to do this in my current android demo scene, so have a look at the demo project to see how I did it there.

No testing has been done on iOS devices.

Current Limitations
-------------------
- Since the fur is made up of shells that are parallel to the surface, the fur can look pretty bad when seen from the side. This is somewhat mitigated by using the blendshape styling but could be further improved by adding in generated fur fins around the contour of the mesh.
- Limitations to skinned meshes. When the fur is applied to skinned meshes, MultiMeshInstance method cannot be used, so a custom mesh is generated with many layers. This is heavy on skinning performance and currently blendshapes are not copied over, so the fur will not adhere to blendshape changes on the base mesh. Using material passes would bypass this issue, but would cause a lot of draw calls. I'm still looking into a solution for this.

Acknowledgements
---------------
- Thanks to my patrons *Little Mouse Games, Winston, Johannes Wuensch, spacechase0, Dmitriy Keane and Marcus Richter* for all their support.
- Kiri (@ExpiredPopsicle) was a huge help in answering questions and pointing me in the right direction with this.

Contributing
------------
If you want to contribute to the project or just work on your own version, clone the repository and add [WAT - Unit Testing Framework](https://github.com/AlexDarigan/WAT-GDScript) into the project as I don't include it in this repository, but I've started using it for running automated tests. I also use [Todo Manager](https://github.com/OrigamiDev-Pete/TODO_Manager) and [Godot Plugin Refresher](https://github.com/godot-extended-libraries/godot-plugin-refresher) when working on the project, so you might want to consider adding them as well. If you want to add something in, simply do a pull request and I'll have a look at it.

License
-------
- ShellFur is under MIT license, see LICENSE.md for details.
- The 3D noise function used for wind is under MIT license by Stefan Gustavson https://github.com/ashima/webgl-noise
