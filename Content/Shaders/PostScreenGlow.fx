#if OPENGL
#define SV_POSITION POSITION
#define VS_SHADERMODEL vs_3_0
#define PS_SHADERMODEL ps_3_0
#elif SM4
#define VS_SHADERMODEL vs_4_0_level_9_3
#define PS_SHADERMODEL ps_4_0_level_9_3
#else
#define SV_POSITION POSITION
#define VS_SHADERMODEL vs_2_0
#define PS_SHADERMODEL ps_2_0
#endif
string description = "Post screen shader for glowing with big radius";

// Glow/bloom post processing effect, adjusted for RacingGameManager.
// Parts are based on NVidias Post_bloom.fx, (c) NVIDIA Corporation 2004
// Also includes a border darken effect with help of screenBorderFadeout.dds.

// This script is only used for FX Composer, most values here
// are treated as constants by the application anyway.
// Values starting with an upper letter are constants.
float Script : STANDARDSGLOBAL
<
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
    string ScriptOutput = "color";

    // We just call a script in the main technique.
    string Script = "Technique=ScreenGlow;";
> = 0.5;

const float DownsampleMultiplicator = 0.25f;
const float4 ClearColor : DIFFUSE = { 0.0f, 0.0f, 0.0f, 1.0f};
const float ClearDepth = 1.0f;

float GlowIntensity <
    string UIName = "Glow intensity";
    string UIWidget = "slider";
    float UIMin = 0.0f;
    float UIMax = 1.0f;
    float UIStep = 0.1f;
> = 0.7f;

// Only used in ps_2_0
float HighlightThreshold <
    string UIName = "Highlight threshold";
    string UIWidget = "slider";
    float UIMin = 0.0f;
    float UIMax = 1.0f;
    float UIStep = 0.1f;
> = 0.975f;

float HighlightIntensity <
    string UIName = "Highlight intensity";
    string UIWidget = "slider";
    float UIMin = 0.0f;
    float UIMax = 1.0f;
    float UIStep = 0.1f;
> = 0.4f;

float radialBlurScaleFactor <
    string UIName = "Radial Blur Scale Factor";
    string UIWidget = "slider";
    float UIMin = -0.1f;
    float UIMax = +0.1f;
    float UIStep = 0.0025f;
> = -0.004f;

// Render-to-Texture stuff
float2 windowSize : VIEWPORTPIXELSIZE;
const float downsampleScale = 0.25;

texture sceneMap : RENDERCOLORTARGET
< 
    float2 ViewportRatio = { 1.0, 1.0 };
    int MIPLEVELS = 1;
>;
sampler sceneMapSampler = sampler_state 
{
    texture = <sceneMap>;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = NONE;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture radialSceneMap : RENDERCOLORTARGET
< 
    float2 ViewportRatio = { 1.0, 1.0 };
    int MIPLEVELS = 1;
>;
sampler radialSceneMapSampler = sampler_state 
{
    texture = <radialSceneMap>;
    AddressU  = CLAMP;        
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = NONE;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture downsampleMap : RENDERCOLORTARGET
< 
    float2 ViewportRatio = { 0.25, 0.25 };
    int MIPLEVELS = 1;
>;
sampler downsampleMapSampler = sampler_state 
{
    texture = <downsampleMap>;
    AddressU  = CLAMP;        
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = NONE;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture blurMap1 : RENDERCOLORTARGET
< 
    float2 ViewportRatio = { 0.25, 0.25 };
    int MIPLEVELS = 1;
>;
sampler blurMap1Sampler = sampler_state 
{
    texture = <blurMap1>;
    AddressU  = CLAMP;        
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = NONE;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture blurMap2 : RENDERCOLORTARGET
< 
    float2 ViewportRatio = { 0.25, 0.25 };
    int MIPLEVELS = 1;
>;
sampler blurMap2Sampler = sampler_state 
{
    texture = <blurMap2>;
    AddressU  = CLAMP;        
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = NONE;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// For the last pass we add this screen border fadeout map to darken the borders
texture screenBorderFadeoutMap : Diffuse
<
    string UIName = "Screen border texture";
    string ResourceName = "ScreenBorderFadeout.dds";
>;
sampler screenBorderFadeoutMapSampler = sampler_state 
{
    texture = <screenBorderFadeoutMap>;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
    AddressW  = CLAMP;
    MIPFILTER = NONE;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// Returns luminance value of col to convert color to grayscale
float Luminance(float3 col)
{
    return dot(col, float3(0.3, 0.59, 0.11));
}

struct VB_OutputPosTexCoord
{
       float4 pos      : SV_POSITION;
    float2 texCoord : TEXCOORD0;
};

struct VB_OutputPos2TexCoords
{
       float4 pos         : SV_POSITION;
    float2 texCoord[2] : TEXCOORD0;
};

struct VB_OutputPos3TexCoords
{
       float4 pos         : SV_POSITION;
    float2 texCoord[3] : TEXCOORD0;
};

struct VB_OutputPos4TexCoords
{
       float4 pos         : SV_POSITION;
    float2 texCoord[4] : TEXCOORD0;
};


VB_OutputPos4TexCoords VS_SimpleBlur(
    uniform float2 direction,
    float4 pos      : SV_POSITION, 
    float2 texCoord : TEXCOORD0)
{
    VB_OutputPos4TexCoords Out = (VB_OutputPos4TexCoords)0;
    Out.pos = pos;
    float2 texelSize = 1.0f / windowSize;

    Out.texCoord[0] = texCoord + texelSize*(float2(2.0f, 2.0f)+direction*(-3.0f));
    Out.texCoord[1] = texCoord + texelSize*(float2(2.0f, 2.0f)+direction*(-1.0f));
    Out.texCoord[2] = texCoord + texelSize*(float2(2.0f, 2.0f)+direction*(+1.0f));
    Out.texCoord[3] = texCoord + texelSize*(float2(2.0f, 2.0f)+direction*(+3.0f));
    
    return Out;
}

VB_OutputPos2TexCoords VS_ScreenQuad(
    float4 pos      : SV_POSITION, 
    float2 texCoord : TEXCOORD0)
{
    VB_OutputPos2TexCoords Out;
    float2 texelSize = 1.0 /
        (windowSize * downsampleScale);
    Out.pos = pos;
    // Don't use bilinear filtering
    Out.texCoord[0] = texCoord + texelSize*0.5;
    Out.texCoord[1] = texCoord + texelSize*0.5;
    return Out;
}

VB_OutputPos3TexCoords VS_ScreenQuadSampleUp(
    float4 pos      : SV_POSITION, 
    float2 texCoord : TEXCOORD0)
{
    VB_OutputPos3TexCoords Out;
    float2 texelSize = 1.0 / windowSize;
    Out.pos = pos;
    // Don't use bilinear filtering
    Out.texCoord[0] = texCoord + texelSize*0.5f;
    Out.texCoord[1] = texCoord + texelSize*0.5f/downsampleScale;
    Out.texCoord[2] = texCoord + (1.0/128.0f)*0.5f;
    return Out;
}


float4 PS_ComposeFinalImage20(
    VB_OutputPos3TexCoords In) : COLOR
{
    float4 orig = tex2D(radialSceneMapSampler, In.texCoord[0]);
    float4 blur = tex2D(blurMap2Sampler, In.texCoord[1]);

    float4 screenBorderFadeout =
        tex2D(screenBorderFadeoutMapSampler, In.texCoord[2]);
        
    float4 ret =
        0.75f*orig +
        GlowIntensity*blur +
        HighlightIntensity*blur.a;
    ret.rgb *= screenBorderFadeout;
    
    // Change colors a bit, sub 20% red and add 25% blue (photoshop values)
    // Here the values are -4% and +5%
    ret.rgb = float3(
        ret.r+0.054f/2,
        ret.g-0.021f/2,
        ret.b-0.035f/2);
    
    // Change brightness -5% and contrast +10%
    ret.rgb = ret.rgb * 0.95f;
    ret.rgb = (ret.rgb - float3(0.5, 0.5, 0.5)) * 1.05f +
        float3(0.5, 0.5, 0.5);

    return ret;
}

//////////////////
// ps_2_0 stuff //
//////////////////

// Works only on ps_2_0 and up
struct VB_OutputPos7TexCoords
{
    float4 pos         : SV_POSITION;
    float2 texCoord[7] : TEXCOORD0;
};

struct VB_OutputPos8TexCoords
{
    float4 pos         : SV_POSITION;
    float2 texCoord[4] : TEXCOORD0;
};

// Blur Width is only used for ps_2_0, ps_1_1 is optimized!
float BlurWidth <
    string UIName = "Blur width";
    string UIWidget = "slider";
    float UIMin = 0.0f;
    float UIMax = 10.0f;
    float UIStep = 0.5f;
> = 8.0f;

VB_OutputPos4TexCoords VS_DownSample20(
    float4 pos : SV_POSITION,
    float2 texCoord : TEXCOORD0)
{
    VB_OutputPos4TexCoords Out;
    float2 texelSize = DownsampleMultiplicator /
        (windowSize * downsampleScale);
    float2 s = texCoord;
    Out.pos = pos;
    
    Out.texCoord[0] = s + float2(-1, -1)*texelSize;
    Out.texCoord[1] = s + float2(+1, +1)*texelSize;
    Out.texCoord[2] = s + float2(+1, -1)*texelSize;
    Out.texCoord[3] = s + float2(+1, +1)*texelSize;
    
    return Out;
}

float4 PS_DownSample20(
    VB_OutputPos4TexCoords In) : COLOR
{
    float4 c;

    // box filter (only for ps_2_0)
    c = tex2D(radialSceneMapSampler, In.texCoord[0])/4;
    c += tex2D(radialSceneMapSampler, In.texCoord[1])/4;
    c += tex2D(radialSceneMapSampler, In.texCoord[2])/4;
    c += tex2D(radialSceneMapSampler, In.texCoord[3])/4;

    // store hilights in alpha, can't use smoothstep version!
    // Fake it with highly optimized version using 80% as treshold.
    float l = Luminance(c.rgb);
    float treshold = 0.75f;
    if (l < treshold)
        c.a = 0;
    else
    {
        l = l-treshold;
        l = l+l+l+l; // bring 0..0.25 back to 0..1
        c.a = l;
    }

    return c;
}


// Blur downsampled map
VB_OutputPos7TexCoords _VS_Blur20(
    float2 direction,
    float4 pos : SV_POSITION, 
    float2 texCoord : TEXCOORD0)
{
    VB_OutputPos7TexCoords Out = (VB_OutputPos7TexCoords)0;
    Out.pos = pos;

    float2 texelSize = BlurWidth / windowSize;
    float2 s = texCoord - texelSize*(7-1)*0.5*direction;
    for (int i=0; i<7; i++)
    {
        Out.texCoord[i] = s + texelSize*i*direction;
    }

    return Out;
}

VB_OutputPos7TexCoords VS_Blur20Horizontal(
	float4 pos : SV_POSITION,
	float2 texCoord : TEXCOORD0)
{
	return _VS_Blur20(float2 (1, 0), pos, texCoord);
}

VB_OutputPos7TexCoords VS_Blur20Vertical(
	float4 pos : SV_POSITION,
	float2 texCoord : TEXCOORD0)
{
	return _VS_Blur20(float2 (0, 1), pos, texCoord);
}

// blur filter weights
const half weights7[7] =
{
    0.05,
    0.1,
    0.2,
    0.3,
    0.2,
    0.1,
    0.05,
};    

float4 PS_Blur20DownSampler(
	VB_OutputPos7TexCoords In) : COLOR
{
	float4 c = 0;

	// this loop will be unrolled by compiler
	for (int i = 0; i<7; i++)
	{
		c += tex2D(downsampleMapSampler, In.texCoord[i]) * weights7[i];
	}

	return c;
}

float4 PS_Blur20BlurSampler(
	VB_OutputPos7TexCoords In) : COLOR
{
	float4 c = 0;

	// this loop will be unrolled by compiler
	for (int i = 0; i<7; i++)
	{
		c += tex2D(blurMap1Sampler, In.texCoord[i]) * weights7[i];
	}

	return c;
}

VB_OutputPos8TexCoords VS_RadialBlur20(
    float4 pos      : SV_POSITION, 
    float2 texCoord : TEXCOORD0)
{
    VB_OutputPos8TexCoords Out;
    float2 texelSize = 1.0 / windowSize;
    Out.pos = pos;
    // Don't use bilinear filtering, correct pixel locations
    
    // This is our original finalSceneMap, reuse existing locations
    Out.texCoord[0] = texCoord + texelSize*0.5f;
    
    // For all radial blur steps scale the finalSceneMap
    float2 texCentered = (texCoord-float2(0.5f, 0.5f))*2.0f;
    
    // Now apply formula to nicely increase blur factor to the borders
    for (int i=1; i<4; i++)
    {
        texCentered = texCentered+
            radialBlurScaleFactor*(0.5f+(i*2)*0.15f)*texCentered*abs(texCentered);
        Out.texCoord[i] = (texCentered+float2(1.0f, 1.0f))/2.0f + texelSize*0.5;
    }
    
    return Out;
}

float4 PS_RadialBlur20(
    VB_OutputPos8TexCoords In) : COLOR
{
    float4 radialBlur = tex2D(sceneMapSampler, In.texCoord[0]);
    for (int i=1; i<4; i++)
        radialBlur += tex2D(sceneMapSampler, In.texCoord[i]);
    return radialBlur/4;
}

// Same for ps_2_0, looks better and allows more control over the parameters.
technique ScreenGlow20
{
    // Generate the radial blur with help of the current scene (finalSceneMap)
    // This pass is quite slow, but for the high quality of the effect we need
    // full screen processing and using a lot of texture fetches.
    pass RadialBlur
    {
        // Disable alpha testing, else most pixels will be skipped
        // because of the highlight HDR technique tricks used here!
        //AlphaTestEnable = false;
        VertexShader = compile VS_SHADERMODEL VS_RadialBlur20();
        PixelShader  = compile PS_SHADERMODEL PS_RadialBlur20();
    }
    
    // Sample full render area down to (1/4, 1/4) of its size!
    pass DownSample
    {
        VertexShader = compile VS_SHADERMODEL VS_DownSample20();
        PixelShader  = compile PS_SHADERMODEL PS_DownSample20();
    }

    pass GlowBlur1
    {
        VertexShader = compile VS_SHADERMODEL VS_Blur20Horizontal();
        PixelShader  = compile PS_SHADERMODEL PS_Blur20DownSampler();
    }

    pass GlowBlur2
    {
        VertexShader = compile VS_SHADERMODEL VS_Blur20Vertical();
        PixelShader  = compile PS_SHADERMODEL PS_Blur20BlurSampler();
    }

    // And compose the final image with the Blurred Glow and the original image.
    pass ComposeFinalScene
    {
        // Save 1 pass by combining the radial blur effect and the compose pass.
        // This pass is not as fast as the previous passes (they were done
        // in 1/16 of the original screen size and executed very fast).
        VertexShader = compile VS_SHADERMODEL VS_ScreenQuadSampleUp();
        PixelShader  = compile PS_SHADERMODEL PS_ComposeFinalImage20();
    }
}
