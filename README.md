# Shell Fur Add-on for Godot Engine

[![Shell Fur Add-on for Godot v0.1.0 Released - Feature Overview](https://user-images.githubusercontent.com/4955051/97077434-8b0f7800-15db-11eb-98eb-7cecf1648304.png)](https://youtu.be/7EUjxwGTPAI "Shell Fur Add-on for Godot v0.1.0 Released - Feature Overview")

Add-on that adds a fur node to Godot 3.2. Demo project available [here.](https://github.com/Arnklit/ShellFurGodotDemo)

[Discord Server](https://discord.gg/mjGvWwQwv2)

[Patreon](https://www.patreon.com/arnklit)

Installation
-----------
Copy the folder *addons/shell_fur* into your project and activate the add-on from the *Project -> Project Settings... -> Plugins* menu.

Purpose
-------
I was inspired by games like Shadow of the Colossus and Red Dead Redemption 2 which uses this technique to try and make my own implementation in Godot.

Usage
-----
Select any *MeshInstance* node and add the *ShellFur* node as a child beneath it.

![uc6ZJWJqa4](https://user-images.githubusercontent.com/4955051/97787441-1bd0ef80-1baa-11eb-8c2b-109b1ace5f36.gif)

&nbsp;
&nbsp;

The parameters for the fur is split into six sections.

Shape
-----

<img align="right" width="400" src="https://user-images.githubusercontent.com/4955051/97784319-93485400-1b95-11eb-9f4d-9b4d280c3da0.png">

**Layers:** Controls how many shells are generated around the object, more layers equals nicer strands, but will decrease performance.

**Pattern Texture:** Manully select the pattern texture used for the fur shape. See info on making your own patterns below.

**Pattern Selector:** Select between 5 included patterns.

**Length:** The length of the fur. Set this to 1.0 if you are using blendshape styling and want the fur to exactly reach the blenshape length.

**Length Rand:** Controls how much randomness there is in the length of the fur.

**Thickness Base:** The thickness at the base of the strand.

**Thickness Tip:** The thickness at the tip of the strand.

&nbsp;

&nbsp;

&nbsp;

*<p align=center>The five built-in fur patterns</p>*

![image](https://user-images.githubusercontent.com/4955051/97798110-fe883980-1c1a-11eb-9efd-66369c21b8d0.png)

Material
--------

<img align="right" width="400" src="https://user-images.githubusercontent.com/4955051/97784402-487b0c00-1b96-11eb-8745-4ace8779f64d.png">

**Base Color:** The colour of the fur at the base of the strand, interpolates linearly towards the tip.

**Tip Color:** The colour of the fur at the tip of the strand, interpolates linearly towards the base.

**Color Texture:** Texture for the colour of the strands. Values are multiplied with Base Color and Tip Color so they can be used for tinting.

**Color Tiling:** UV Tiling for Color Texture.

**Transmission:** The amount of light that can pass through the fur and the colour of that light.

**Ao:** Fake ambient occlusion applied linearly from the base to the tip.

**Roughness** The roughness value of the fur, it's difficult to achieve realistic shiny fur with this approach, you will probably get the best result leaving this value at 1.0.

**Normal Adjustment** This parameter attempts to correct the normal to be along the strand, rather than using the normal of the base mesh. Most of the time it actually seems to look best to leave this low, so the fur get's shaded in the shape of the base mesh, but if you are using thick strands or need specular highlights, you may need to adjust this.

&nbsp;

&nbsp;

Physics
-------

<img align="right" width="400" src="https://user-images.githubusercontent.com/4955051/97785969-31411c00-1ba0-11eb-96e7-243eda4c6ff6.png">

**Custom Physics Pivot** If you are using the fur on a skinned mesh where animation is moving the mesh, use this option to set the physics pivot to the center of gravity of your character. You can use the *Bone Attachment* node to set up a node that will follow a specific bone in your rig.

**Gravity:** Down force applied on the spring physics.

**Spring:** Ammount of springiness to the physics.

**Damping:** Ammount of damping to the physics (to imitate air and friction resistance stopping the fur's movement over time)

**Wind Strength** Ammount of wind strength, the wind is applied as a noise distortion in the vertex shader due to current limitations so it does not interact with the spring physics. If the *Wind Strength* is set to 0 the calculations are skipped in the shader.

**Wind Speed** How quickly the wind noise moves accros the fur.

**Wind Scale** Scale of the wind noise

**Wind Angle** The angle the wind pushes in degrees around the Y-axis. 0 means the wind is blowing in X- direction.

&nbsp;

&nbsp;

*<p align=center>Example of physics forces with a Custom Physics Pivot set</p>*
<p align="center">
  <img src="https://user-images.githubusercontent.com/4955051/97798318-fcbf7580-1c1c-11eb-8385-af9971fdd95b.gif">
</p>

Blendshape Styling
------------------

<img align="right" width="400" src="https://user-images.githubusercontent.com/4955051/97786353-e379e300-1ba2-11eb-884b-a4a53b1c2eb9.png">

**Blendshape Index:** Use this option to style the fur with a blendshape. A value of -1 means disabled.

**Normal Bias:** This option is used in conjunction with blendshape index. It mixes in the normal direction at the base.

&nbsp;

Lod
---

<img align="right" width="400" src="https://user-images.githubusercontent.com/4955051/97787660-8b93aa00-1bab-11eb-998f-8bb6156a354d.png">

**Lod 0 Distance:** The distance up to which the fur will display at full detail.

**Lod 1 Distance:** This distance at which the fur will display at 25% of it's layers. The fur will smoothly interpolate between *Lod 0* and *Lod 1*. Beyond *Lod 1* distance the fur will fade away and the fur object will become hidden.

&nbsp;

Advanced
--------

<img align="right" width="400" src="https://user-images.githubusercontent.com/4955051/97787878-aadf0700-1bac-11eb-91f3-fb8ec0fc7194.png">

**Cast Shadow** Whether the fur should cast shadow. This is expensive performance wise, so it defaults to off.

**Custom Shader** Option to use a custom shader for the fur. Selecting new will create a copy of the default shader for you to edit.

&nbsp;

TIPS
----

**Using your own fur patterns**

You can use any type of noise as a pattern, but if you want to be able to have random lengths on the fur strand you will need to set up the green channel with cells with random greyscale values that present each strands length when randomness is applied.

Breakdown of Fine texture - Left: Combined pattern texture, Middle: R channel, Right: G channel.

![image](https://user-images.githubusercontent.com/4955051/95909140-e64c9980-0d95-11eb-8a78-9f864b7abe19.png)

**Mobile Support - experimental**

The shader does not work with GLES 2.0. So if your target device doesn't support GLES 3.0 the fur will not work.

There is a *shell_fur_mobile.shader* file located in *addons/shell_fur/shaders* that you can use with the *Custom Shader* option under the *Advanced* section. It has *depth_draw_alpha_prepass* disabled (since that appeared buggy in my android testing) and has *shadows_disabled* set for performance improvements.

In my testing there appeared to be a bug where skinned meshes with blendshapes don't render on Android. https://github.com/godotengine/godot/issues/43217. So if you want to use blendshape styling, you might need to work around this by having a seperate mesh where you have removed the blendshape that is getting rendered. I had to do this in my current android demo scene, so have a look at the demo project to see how I did it there.

No testing has been done on iOS devices.

Current Limitations
-------------------
- Since the fur is made up of shells that are paralel to the surface, the fur can look pretty bad when seen from the side. This is somewhat mitigated by using the blendshape styling but could be further improved by adding in generated fur fins around the contour of the mesh.
- Limitations to skinned meshes. When the fur is applied to skinned meshes, MultiMeshInstance method cannot be used, so a custom mesh is generated with many layers. This is heavy on skinning performance and currently blendshapes are not copied over, so the fur will not adhere to blendshape changes on the base mesh. Using material passes would bypass this issue, but would cause a lot of drawcalls. I'm still looking into a solution for this.

Acknowledgements
---------------
* Thanks to my patrons *Marcus Richter, Dmitriy Keane, spacechace0 and Johannes Wuesnch* for all their support.
* Kiri (@ExpiredPopsicle) was a huge help in answering questions and pointing me in the right direction with this.
