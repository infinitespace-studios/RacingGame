#if OPENGL
#define SV_POSITION POSITION
#define VS_SHADERMODEL vs_3_0
#define PS_SHADERMODEL ps_3_0
#elif SM4
#define VS_SHADERMODEL vs_4_0_level_9_1
#define PS_SHADERMODEL ps_4_0_level_9_1
#else
#define SV_POSITION POSITION
#define VS_SHADERMODEL vs_2_0
#define PS_SHADERMODEL ps_2_0
#endif
string description = "Line rendering helper shader for XNA";

// Default variables, supported by the engine
float4x4 worldViewProj : WorldViewProjection;

struct VertexInput
{
    float3 pos   : SV_POSITION;
    float4 color : COLOR;
};

struct VertexOutput 
{
   float4 pos   : SV_POSITION;
   float4 color : COLOR;
};

VertexOutput LineRenderingVS(VertexInput In)
{
    VertexOutput Out;
    
    // Transform position
    Out.pos = mul(float4(In.pos, 1), worldViewProj);
    Out.color = In.color;

    // And pass everything to the pixel shader
    return Out;
}

float4 LineRenderingPS(VertexOutput In) : Color
{
    return In.color;
}

VertexOutput LineRendering2DVS(VertexInput In)
{
    VertexOutput Out;
    
    // Transform position (just pass over)
    Out.pos = float4(In.pos, 1);
    Out.color = In.color;

    // And pass everything to the pixel shader
    return Out;
}

float4 LineRendering2DPS(VertexOutput In) : Color
{
    return In.color;
}

// Techniques
technique LineRendering3D
{
    pass PassFor3D
    {
        VertexShader = compile VS_SHADERMODEL LineRenderingVS();
        PixelShader = compile PS_SHADERMODEL LineRenderingPS();
    }
}

technique LineRendering2D
{
    pass PassFor2D
    {
        VertexShader = compile VS_SHADERMODEL LineRendering2DVS();
        PixelShader = compile PS_SHADERMODEL LineRendering2DPS();
    }
}
