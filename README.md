# snapdragon-gsr
Snapdragon Game Super Resolution for Unity BIRP

For more information and up-to-date versions, check the official GSR git page:
[Snapdragon GSR GitHub](https://github.com/SnapdragonStudios/snapdragon-gsr?tab=readme-ov-file)

## Quick Readme (also included in the HLSL file)

1. Include the `sgsr_mobile.hlsl` file in your post-process shader.

2. Use the `UNITY_DECLARE_TEX2D` Macro as it takes care of both the Texture and Sampler declaration, like so:
    ```hlsl
    UNITY_DECLARE_TEX2D(_MainTex);
    ```

3. Declare this additional sampler. I believe the one declared with the `UNITY_DECLARE_TEX2D` macro is enough, but just in case:
    ```hlsl
    SamplerState sampler_LinearClamp;
    ```

4. Call the `SgsrYuvH` function in your post-process fragment shader.

### Function Parameters Explanation:

- **_MainTex_TexelSize**: Should be a `float4` containing `{1.0/low_res_tex_width, 1.0/low_res_tex_height, low_res_tex_width, low_res_tex_height}`.
  - The `xy` components will be used to shift UVs to read adjacent texels.
  - The `zw` components will be used to map from UV space `[0, 1][0, 1]` to image space `[0, w][0, h]`.
  
- **c**: Your screen-sampled color.
- **i.uv**: Screen space UVs.
- **_MainTex_TexelSize**: Configured the same way as `ViewportInfo`.

Example usage:
```hlsl
SgsrYuvH(c, i.uv, _MainTex_TexelSize);
