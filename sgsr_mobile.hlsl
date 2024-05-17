//============================================================================================================
//
//
//                  Copyright (c) 2023, Qualcomm Innovation Center, Inc. All rights reserved.
//                              SPDX-License-Identifier: BSD-3-Clause
//
//============================================================================================================

////////////////////////
// USER CONFIGURATION //
////////////////////////

/*
* Operation modes:
* RGBA -> 1
* RGBY -> 3
* LERP -> 4
*/
#define OperationMode 1

#define EdgeThreshold 8.0/255.0

#define EdgeSharpness 2.0

////////////////////////
////////////////////////
// USAGE EXAMPLE://

// 1 - Include this file in your post process shader
// 2 - In BIRP use the UNITY_DECLARE_TEX2D Macro as it takes care of both the Texture and Sampler declaration
//UNITY_DECLARE_TEX2D(_MainTex);

// 3 - Declare this additional sampler, i believe the one declared with the UNITY_DECLARE_TEX2D macro is enough but just in case
//SamplerState sampler_LinearClamp;

// 4 - Call this SgsrYuvH function in your post process frag shader. Functions params explanation:
// ViewportInfo should be a float4 containing {1.0/low_res_tex_width, 1.0/low_res_tex_height, low_res_tex_width, low_res_tex_height}.
// The `xy` components will be used to shift UVs to read adjacent texels.
// The `zw` components will be used to map from UV space [0, 1][0, 1] to image space [0, w][0, h].
// c is your screen sampled color, i.uv are screen space UVs and _MainTex_TexelSize is configured the same was as ViewportInfo
//SgsrYuvH(c, i.uv, _MainTex_TexelSize);

// ///////SGSR_GL_Mobile.frag/////////////////////////////////////////
half4 SGSRRH(float2 p)
{
	half4 res = _MainTex.GatherRed(sampler_LinearClamp, p);
	return res;
}
half4 SGSRGH(float2 p)
{
	half4 res = _MainTex.GatherGreen(sampler_LinearClamp, p);
	return res;
}
half4 SGSRBH(float2 p)
{
	half4 res = _MainTex.GatherBlue(sampler_LinearClamp, p);
	return res;
}
half4 SGSRAH(float2 p)
{
	half4 res = _MainTex.GatherAlpha(sampler_LinearClamp, p);
	return res;
}
half4 SGSRRGBH(float2 p)
{
	half4 res = _MainTex.SampleLevel(sampler_LinearClamp, p, 0);
	return res;
}

half4 SGSRH(float2 p, uint channel)
{
	if (channel == 0)
		return SGSRRH(p);
	if (channel == 1)
		return SGSRGH(p);
	if (channel == 2)
		return SGSRBH(p);
	return SGSRAH(p);
}

half fastLanczos2(half x)
{
	half wA = x- half(4.0);
	half wB = x*wA-wA;
	wA *= wA;
	return wB*wA;
}
half2 weightY(half dx, half dy, half c, half std)
{
	half x = ((dx*dx)+(dy* dy))* half(0.5) + clamp(abs(c)*std, 0.0, 1.0);
	half w = fastLanczos2(x);
	return half2(w, w * c);
}

void SgsrYuvH(
	out half4 pix,
	float2 uv,
	float4 con1)
{
	const int mode = OperationMode;
	half edgeThreshold = EdgeThreshold;
	half edgeSharpness = EdgeSharpness;

	// Sample the low res texture using current texture coordinates (in UV space).
	if(mode == 1)
		pix.xyz = SGSRRGBH(uv).xyz;
	else
		pix.xyzw = SGSRRGBH(uv).xyzw;
	float xCenter;
	xCenter = abs(uv.x+-0.5);
	float yCenter;
	yCenter = abs(uv.y+-0.5);

	//todo: config the SR region based on needs
	//if ( mode!=4 && xCenter*xCenter+yCenter*yCenter<=0.4 * 0.4)
	if ( mode!=4)
	{
		// Compute the coordinate for the center of the texel in image space.
		float2 imgCoord = ((uv.xy*con1.zw)+ float2(-0.5,0.5));
		float2 imgCoordPixel = floor(imgCoord);
		// Remap the coordinate for the center of the texel in image space to UV space.
		float2 coord = (imgCoordPixel*con1.xy);
		half2 pl = (imgCoord+(-imgCoordPixel));
		// Gather the `[mode]` components (ex: `.y` if mode is 1) of the 4 texels located around `coord`.
		half4 left = SGSRH(coord, mode);

		half edgeVote = abs(left.z - left.y) + abs(pix[mode] - left.y)  + abs(pix[mode] - left.z) ;
		if(edgeVote > edgeThreshold)
		{
			// Shift coord to the right by 1 texel. `coord` will be pointing to the same texel originally sampled
			// l.84 or 86 (The texel at UV in_TEXCOORD0 in the low res texture).
			coord.x += con1.x;

			// Gather components for the texels located to the right of coord (the original sampled texel).
			half4 right = SGSRH(coord + float2(con1.x,  0.0), mode);
			// Gather components for the texels located to up and down of coord (the original sampled texel).
			half4 upDown;
			upDown.xy = SGSRH(coord + float2(0.0, -con1.y), mode).wz;
			upDown.zw = SGSRH(coord + float2(0.0,  con1.y), mode).yx;

			half mean = (left.y+left.z+right.x+right.w)* half(0.25);
			left = left - half4(mean,mean,mean,mean);
			right = right - half4(mean, mean, mean, mean);
			upDown = upDown - half4(mean, mean, mean, mean);
			pix.w =pix[mode] - mean;

			half sum = (((((abs(left.x)+abs(left.y))+abs(left.z))+abs(left.w))+(((abs(right.x)+abs(right.y))+abs(right.z))+abs(right.w)))+(((abs(upDown.x)+abs(upDown.y))+abs(upDown.z))+abs(upDown.w)));
			half std = half(2.181818)/sum;

			half2 aWY = weightY(pl.x, pl.y+1.0, upDown.x,std);
			aWY += weightY(pl.x-1.0, pl.y+1.0, upDown.y,std);
			aWY += weightY(pl.x-1.0, pl.y-2.0, upDown.z,std);
			aWY += weightY(pl.x, pl.y-2.0, upDown.w,std);			
			aWY += weightY(pl.x+1.0, pl.y-1.0, left.x,std);
			aWY += weightY(pl.x, pl.y-1.0, left.y,std);
			aWY += weightY(pl.x, pl.y, left.z,std);
			aWY += weightY(pl.x+1.0, pl.y, left.w,std);
			aWY += weightY(pl.x-1.0, pl.y-1.0, right.x,std);
			aWY += weightY(pl.x-2.0, pl.y-1.0, right.y,std);
			aWY += weightY(pl.x-2.0, pl.y, right.z,std);
			aWY += weightY(pl.x-1.0, pl.y, right.w,std);

			half finalY = aWY.y/aWY.x;

			half max4 = max(max(left.y,left.z),max(right.x,right.w));
			half min4 = min(min(left.y,left.z),min(right.x,right.w));
			finalY = clamp(edgeSharpness*finalY, min4, max4);

			half deltaY = finalY -pix.w;

			pix.x = saturate((pix.x+deltaY));
			pix.y = saturate((pix.y+deltaY));
			pix.z = saturate((pix.z+deltaY));
		}
	}
	pix.w = 1.0;  //assume alpha channel is not used

}
////////////////////////////////////////////////////////////////////////