#ifndef FEEL_VERTEX_INCLUDED
#define FEEL_VERTEX_INCLUDED


//  Feel_Vertex.hlsl — 버텍스 셰이더
//  월드 공간 위치·노멀·탄젠트·바이탄젠트 출력.


#include "Feel_Input.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

Varyings FeelVertex(Attributes input)
{
    //인스턴스 설정
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs posInputs    = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs   normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    output.positionCS  = posInputs.positionCS;
    output.positionWS  = posInputs.positionWS;
    output.normalWS    = normalInputs.normalWS;
    output.tangentWS   = normalInputs.tangentWS;
    output.bitangentWS = normalInputs.bitangentWS;
    output.uv          = input.uv;
    output.color       = input.color;
    output.vertexSH    = SampleSH(normalInputs.normalWS);

    return output;
}

#endif // FEEL_VERTEX_INCLUDED