# Lit Material Inspector Reference

You can modify the properties of a Lit material in the Lit Material Inspector.

Refer to [Lit material](lit-material.md) for more information.

## Properties

[!include[](snippets/shader-properties/surface-options/lit-surface-options.md)]


### Vertex Animation

| **Property**                           | **Description**                                              |
| -------------------------------------- | ------------------------------------------------------------ |
| **Motion Vectors For Vertex Animation** | Enable the checkbox to make HDRP write motion vectors for GameObjects that use vertex animation. This removes the ghosting that vertex animation can cause. |

<a name="surface-inputs"></a>

### Surface Inputs

| **Property**                    | **Description**                                              |
| ------------------------------- | ------------------------------------------------------------ |
| **Base Map**                    | Assign a Texture that controls both the color and opacity of your Material. To assign a Texture to this field, click the radio button and select your Texture in the Select Texture window. Use the color picker to select the color of the Material. If you do not assign a Texture, this is the absolute color of the Material. If you do assign a Texture, the final color of the Material is a combination of the Texture you assign and the color you select. The alpha value of the color controls the transparency level for the Material if you select **Transparent** from the **Surface Type** drop-down. |
| **Metallic**                    | Use this slider to adjust how "metal-like" the surface of your Material is (between 0 and 1). When a surface is more metallic, it reflects the environment more and its albedo color becomes less visible. At full metallic level, the surface color is entirely driven by reflections from the environment. When a surface is less metallic, its albedo color is clearer and any surface reflections are visible on top of the surface color, rather than obscuring it.<br />This property only appears when you unassign the Texture in the **Mask Map**. |
| **Smoothness**                  | Use the slider to adjust the smoothness of your Material. Every light ray that hits a smooth surface bounces off at predictable and consistent angles. For a perfectly smooth surface that reflects light like a mirror, set this to a value of 1. Less smooth surfaces reflect light over a wider range of angles (because the light hits the bumps in the microsurface), so the reflections have less detail and spread across the surface in a more diffused pattern.<br />This property only appears when you unassign the Texture in the **Mask Map**. |
| **Alpha Remapping**             | Use this min-max slider to remap the alpha values from the **Base Map** to the range you specify. Rather than [clamping](https://docs.unity3d.com/ScriptReference/Mathf.Clamp.html) values to the new range, Unity condenses the original range down to the new range uniformly.<br />This property only appears when you assign a **Base Map**. |
| **Metallic Remapping**          | Use this min-max slider to remap the metallic values from the **Mask Map** to the range you specify. Rather than [clamping](https://docs.unity3d.com/ScriptReference/Mathf.Clamp.html) values to the new range, Unity condenses the original range down to the new range uniformly.<br />This property only appears when you assign a **Mask Map**. |
| **Smoothness Remapping**        | Use this min-max slider to remap the smoothness values from the **Mask Map** to the range you specify. Rather than [clamping](https://docs.unity3d.com/ScriptReference/Mathf.Clamp.html) values to the new range, Unity condenses the original range down to the new range uniformly.<br />This property only appears when you assign a **Mask Map**. |
| **Ambient Occlusion Remapping** | Use this min-max slider to remap the ambient occlusion values from the **Mask Map** to the range you specify. Rather than [clamping](https://docs.unity3d.com/ScriptReference/Mathf.Clamp.html) values to the new range, Unity condenses the original range down to the new range uniformly.<br />This property only appears when you assign a **Mask Map**. |
| **Mask Map**                    | Assign a [channel-packed Texture](Glossary.md#ChannelPacking) with the following Material maps in its RGBA channels.<br />&#8226; **Red**: Stores the metallic map. <br />&#8226; **Green**: Stores the ambient occlusion map.<br />&#8226; **Blue**: Stores the detail mask map.<br />&#8226; **Alpha**: Stores the smoothness map.<br />For more information on channel-packed Textures and the mask map, see [mask map](Mask-Map-and-Detail-Map.md#MaskMap). |
| **Normal Map Space**            | Use this drop-down to select the type of Normal Map space that this Material uses.<br />&#8226; **TangentSpace**: Defines the normal map in [tangent space](Glossary.md#TangentSpaceNormalMap). use this to tile a Texture on a Mesh. The normal map Texture must be BC7, BC5, or DXT5nm format.<br />&#8226; **ObjectSpace**: Defines the normal maps in [object space](Glossary.md#ObjectSpaceNormalMap). Use this for planar-mapping GameObjects like the terrain. The normal map must be an RGB Texture . |
| **Normal Map**                  | Assign a Texture that defines the normal map for this Material in tangent space. Use the slider to modulate the normal intensity between 0 and 8.<br />This property only appears when you select **TangentSpace** from the **Normal Map Space** drop-down. |
| **Normal Map OS**               | Assign a Texture that defines the object space normal map for this Material. Use the handle to modulate the normal intensity between 0 and 8.<br />This property only appears when you select **ObjectSpace** from the **Normal Map Space** drop-down. |
| **Bent Normal Map**             | Assign a Texture that defines the bent normal map for this Material in tangent space. HDRP uses bent normal maps to simulate more accurate ambient occlusion.  Note: Bent normal maps only work with diffuse lighting.<br />This property only appears when you select **TangentSpace** from the **Normal Map Space** drop-down.. |
| **Bent Normal Map OS**          | Assign a Texture that defines the bent normal map for this Material in object space. HDRP uses bent normal maps to simulate more accurate ambient occlusion. Note: Bent normal maps only work with diffuse lighting.<br />This property only appears when you select **ObjectSpace** from the **Normal Map Space** drop-down. |
| **Coat Mask**                   | Assign a Texture that defines the coat mask for this Material. HDRP uses this mask to simulate a clear coat effect on the Material to mimic Materials like car paint or plastics. The Coat Mask value is 0 by default, but you can use the handle to modulate the clear Coat Mask effect using a value between 0 and 1. |
| **Base UV Mapping**             | Use the drop-down to select the type of UV mapping that HDRP uses to map Textures to this Material’s surface.<br />&#8226; Unity manages four UV channels for a vertex: **UV0**, **UV1**, **UV2**, and **UV3**.<br />&#8226; **Planar:** A planar projection from top to bottom.<br />&#8226; **Triplanar**: A planar projection in three directions:<br />X-axis: Left to right<br />Y-axis: Top to bottom<br />Z-axis: Front to back<br /><br />Unity blends these three projections together to produce the final result. |
| **Tiling**                      | Set an **X** and **Y** UV tile rate for all of the Textures in the **Surface Inputs** section. HDRP uses the **X** and **Y** values to tile these Textures across the Material’s surface, in object space. |
| **Offset**                      | Set an **X** and **Y** UV offset for all of the Textures in the **Surface Inputs** section. HDRP uses the **X** and **Y** values to offset these Textures across the Material’s surface, in object. |

### Detail Inputs

[!include[](snippets/shader-properties/detail-inputs.md)]

### Transparency Inputs

Unity exposes this section if you select **Transparent** from the **Surface Type** drop-down. For information on the properties in this section, see the [Surface Type documentation](Surface-Type.md#TransparencyInputs).

Be aware that when you enable **Refraction**, make sure to set **Blend Mode** to **Alpha**, otherwise the effect does not work as expected. If you enable **Refraction** and use a **Blend Mode** other than **Alpha**, a warning displays in the material Inspector.

Also, be aware that HDRP does not support **Refraction** in the **Pre-Refraction** render pass. If you enable **Refraction** and use the **Pre-Refraction** render pass, a warning displays in the material and Shader Graph Inspector.

<a name="EmissionInputs"></a>

### Emission inputs

| **Property**                    | **Description**                                              |
| ------------------------------- | ------------------------------------------------------------ |
| **Use Emission Intensity**      | Enable the checkbox to use a separate LDR color and intensity value to set the emission color for this Material. Disable this checkbox to only use an HDR color to handle the color and emission color intensity. When enabled, this exposes the **Emission Intensity** property. |
| **Emission Map**                | Assign a Texture that this Material uses for emission. You can also use the color picker to select a color that HDRP multiplies by the Texture. If you do not set an emission texture then HDRP only uses the HDR color to calculate the final emissive color of the Material. You can set the intensity of the HDR color within the HDR color picker. |
| **Emission UV Mapping**         | Use the drop-down to select the type of UV mapping that HDRP uses for the **Emission Map**.<br />&#8226; Unity manages four UV channels for a vertex: **UV0**, **UV1**, **UV2**, and **UV3**.<br />&#8226; **Planar:** A planar projection from top to bottom.<br />&#8226; **Triplanar**: A planar projection in three directions:<br />X-axis: Left to right<br />Y-axis: Top to bottom<br />Z-axis: Front to back<br /><br />Unity blends these three projections together to produce the final result.<br />&#8226; **Same as Base**: Unity will use the **Base UV Mapping** selected in the **Surface Inputs**. If the Surface has **Pixel displacement** enabled, this option will apply displacement on the emissive map too. |
| **- Tiling**                    | Set an **X** and **Y** tile rate for the **Emission Map** UV. HDRP uses the **X** and **Y** values to tile the Texture assigned to the **Emission Map** across the Material’s surface, in object space. |
| **- Offset**                    | Set an **X** and **Y** offset for the **Emission Map** UV. HDRP uses the **X** and **Y** values to offset the Texture assigned to the **Emission Map** across the Material’s surface, in object space. |
| **Emission Intensity**          | Set the overall strength of the emission effect for this Material.<br />Use the drop-down to select one of the following [physical light units](Physical-Light-Units.md) to use for intensity:<br />&#8226; [Nits](Physical-Light-Units.md#Nits)<br />&#8226; [EV<sub>100</sub>](Physical-Light-Units.md#EV) |
| **Exposure Weight**             | Use the slider to set how much effect the exposure has on the emission power. For example, if you create a neon tube, you would want to apply the emissive glow effect at every exposure. |
| **Emission Multiply with Base** | Enable the checkbox to make HDRP use the base color of the Material when it calculates the final color of the emission. When enabled, HDRP multiplies the emission color by the base color to calculate the final emission color. |
| **Emission**                    | Toggles whether emission affects global illumination. |
| **- Global Illumination**       | The mode HDRP uses to determine how color emission interacts with global illumination.<br />&#8226; **Realtime**: Select this option to make emission affect the result of real-time global illumination.<br />&#8226; **Baked**: Select this option to make emission only affect global illumination during the baking process.<br />&#8226; **None**: Select this option to make emission not affect global illumination. |

### Advanced options

<table>
<tr>
<th>Property</th>
<th>Description</th>
</tr>
[!include[](snippets/shader-properties/advanced-options/enable-gpu-instancing.md)]
[!include[](snippets/shader-properties/advanced-options/specular-occlusion-mode.md)]
[!include[](snippets/shader-properties/advanced-options/add-precomputed-velocity.md)]
</table>
