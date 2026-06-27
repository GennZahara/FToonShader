#ifndef FEEL_OUTLINE_INCLUDED
#define FEEL_OUTLINE_INCLUDED

// Feel_Outline.hlsl — Inverted Hull 아웃라인 모듈.
// 클립 공간에서 노멀 방향으로 밀어내 외곽선을 생성.
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


// 아웃라인 전용 구조체
//  ForwardLit Pass의 Attributes/Varyings와 이름 충돌 방지 신경쓰기.

struct OutlineAttributes //(Cpu->Vertex)
{
    float4 positionOS : POSITION;
    float3 normalOS   : NORMAL;
    float4 color      : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct OutlineVaryings //(Vertex->GPU)
{
    float4 positionCS : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


// Vertex Shader
//  클립 공간에서 노멀 방향으로 밀어내는 방식.
//  → 거리·해상도에 관계없이 화면 픽셀 두께 일정 (월드 공간 방식 대비 안정적).
//  positionCS.w 곱: perspective divide 전후 두께 일관성 보정.
OutlineVaryings OutlineVertex(OutlineAttributes input)
{
    OutlineVaryings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs   normalInput = GetVertexNormalInputs(input.normalOS);

    // 클립 공간 노멀 (화면 공간에서 일정한 두께를 얻기 위해 클립 공간에서 밀어냄)
    float3 normalCS  = TransformWorldToHClipDir(normalInput.normalWS, true);

    // vertex color a채널으로 부위별 두께 마스크 적용
    half widthMask   = input.color.a;
    half scaledWidth = _OutlineWidth * widthMask * 0.01;

    output.positionCS = vertexInput.positionCS;
    // positionCS.w 곱: perspective divide 전후 두께 일관성 보정
    output.positionCS.xy += normalCS.xy * scaledWidth * output.positionCS.w;

    return output;
}


// Fragment Shader
float4 OutlineFragment(OutlineVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    // 디버그 출력 중에는 아웃라인 숨김 — 중간값 시각화를 가리지 않도록
    // (_DebugMode는 각 셰이더 Fragment의 CBUFFER에서 선언, 이 파일보다 먼저 include됨)
    if (_DebugMode > 0.5) discard;

    return _OutlineColor;
}


#endif // FEEL_OUTLINE_INCLUDED