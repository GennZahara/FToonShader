#ifndef FEEL_INPUT_INCLUDED
#define FEEL_INPUT_INCLUDED

//  Feel_Input.hlsl — 버텍스 I/O 구조체
//  Attributes / Varyings 구조체만 선언.
//  CBUFFER(UnityPerMaterial)는 각 Fragment 파일에서 선언하여
//  Feel_Main / Feel_Face 두 셰이더가 독립적인 프로퍼티 세트를 가질 수 있도록 함.

//Core.hlsl를 여기에 include하는 이유
//공간변환, 인스턴싱, 기본 타입/상수등을 여기서 제공받는데, 매번 모든 Fragment에서 include할 필요없이
//여기서 받아가도록 하려고
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// 버텍스 입력 (Cpu->Vertex)
struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS   : NORMAL;
    float4 tangentOS  : TANGENT;
    float2 uv         : TEXCOORD0;
    float4 color      : COLOR;      
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// 버텍스 출력 / 프래그먼트 입력 (Vertex->GPU)
struct Varyings
{
    float4 positionCS  : SV_POSITION;
    float3 positionWS  : TEXCOORD0;
    float2 uv          : TEXCOORD1;
    float3 normalWS    : TEXCOORD2;
    float3 tangentWS   : TEXCOORD3;
    float3 bitangentWS : TEXCOORD4;
    float4 color       : TEXCOORD5;
    float3 vertexSH    : TEXCOORD6;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

#endif // FEEL_INPUT_INCLUDED